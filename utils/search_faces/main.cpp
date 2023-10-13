#include <chrono>
#include <cstdint>
#include <filesystem>
#include <immintrin.h>
#include <iostream>
#include <vector>

#include "absl/container/flat_hash_map.h"
#include "absl/container/flat_hash_set.h"
#include "absl/strings/string_view.h"
#include "absl/strings/substitute.h"
#include "absl/time/time.h"
#include "boost/program_options.hpp"
#include "boost/property_tree/ini_parser.hpp"
#include "cpr/cpr.h"
#include "crow/json.h"
#include "mysqlx/xdevapi.h"

using namespace std;
namespace po = boost::program_options;

using DateTime = absl::Time;

template <typename T>
using HashSet = absl::flat_hash_set<T>;

const int DESCRIPTOR_SIZE = 512;
typedef float Data[DESCRIPTOR_SIZE];
const auto EVENT_TYPES = {"нет", "неотвеченный вызов", "отвеченный вызов", "открытие ключом", "открытие приложением", "открытие по лицу", "открытие по коду", "открытие звонком"};

static constexpr const char* PARAM_HELP = "help";
static constexpr const char* PARAM_CONFIG = "config";
static constexpr const char* PARAM_TOLERANCE = "tolerance";
static constexpr const char* PARAM_GROUP_ID = "group_id";
static constexpr const char* PARAM_OUTPUT_TYPE = "output_type";
static constexpr const char* PARAM_EVENTS = "events";
static constexpr const char* PARAM_FRS_LOGS = "frs_logs";
static constexpr const char* PARAM_INFO = "info";
static constexpr const char* PARAM_START_DATE = "start_date";
static constexpr const char* PARAM_END_DATE = "end_date";
static constexpr const char* DATE_NOW = "now";
static constexpr const char* DATE_FORMAT = "%Y-%m-%d";
static constexpr const char* EVENT_DATE_FORMAT = "%Y-%m-%d %H:%M:%S";
static constexpr const char* DATA_FILE_SUFFIX = ".dat";

static constexpr const char* OUTPUT_TYPE_TEXT = "text";
static constexpr const char* OUTPUT_TYPE_JSON = "json";

// бинарные данные события для хранения и дальнейшего применения
struct EventData
{
  char event_id[32];  // внутренний идентификатор события
  int32_t position;   // позиция дескриптора (нумерация начинается с нуля)
  Data data;          // данные дескриптора (вектора)
} __attribute__((packed));

struct DescriptorData
{
  Data data;  // данные дескриптора (вектора)
} __attribute__((packed));

struct ResultItem
{
  string event_date;
  string event_id;   // идентификатор из журнала FRS (имя файла со скриншотом без расширения)
  string uuid;       // идентификатор события dm
  string url_image;  // URL кадра
  string info;       // дополнительная информация по событию
  int id_descriptor = 0;
  double similarity = -1.0;

  bool operator>(const ResultItem& other) const
  {
    return event_date > other.event_date;
  }
};

const constexpr char* SQL_GET_SG_FACE_DESCRIPTORS = R"_SQL_(
  select
    fd.id_descriptor,
    fd.descriptor_data
  from
    link_descriptor_sgroup ldsg
    inner join face_descriptors fd
      on ldsg.id_descriptor = fd.id_descriptor
  where
    ldsg.id_sgroup = ?;
 )_SQL_";

inline float reduceSum(const __m256& a)
{
  __m256 s0 = _mm256_hadd_ps(a, a);
  s0 = _mm256_hadd_ps(s0, s0);
  __m128 s1 = _mm256_extractf128_ps(s0, 1);
  s1 = _mm_add_ps(_mm256_castps256_ps128(s0), s1);
  return _mm_cvtss_f32(s1);
}

inline double cosineDistanceSIMD(const Data& d1, const Data& d2)
{
  int step = 8;
  __m256 sum0 = _mm256_setzero_ps();
  __m256 sum1 = _mm256_setzero_ps();
  __m256 sum2 = _mm256_setzero_ps();
  __m256 sum3 = _mm256_setzero_ps();
  __m256 sum0_sqr1 = _mm256_setzero_ps();
  __m256 sum1_sqr1 = _mm256_setzero_ps();
  __m256 sum2_sqr1 = _mm256_setzero_ps();
  __m256 sum3_sqr1 = _mm256_setzero_ps();
  __m256 sum0_sqr2 = _mm256_setzero_ps();
  __m256 sum1_sqr2 = _mm256_setzero_ps();
  __m256 sum2_sqr2 = _mm256_setzero_ps();
  __m256 sum3_sqr2 = _mm256_setzero_ps();
  __m256 a0;
  __m256 b0;

  for (int i = 0; i < DESCRIPTOR_SIZE; i += 4 * step)
  {
    a0 = _mm256_loadu_ps(d1 + i + 0 * step);
    b0 = _mm256_loadu_ps(d2 + i + 0 * step);
    sum0 = _mm256_add_ps(sum0, _mm256_mul_ps(a0, b0));
    sum0_sqr1 = _mm256_add_ps(sum0_sqr1, _mm256_mul_ps(a0, a0));
    sum0_sqr2 = _mm256_add_ps(sum0_sqr2, _mm256_mul_ps(b0, b0));

    a0 = _mm256_loadu_ps(d1 + i + 1 * step);
    b0 = _mm256_loadu_ps(d2 + i + 1 * step);
    sum1 = _mm256_add_ps(sum1, _mm256_mul_ps(a0, b0));
    sum1_sqr1 = _mm256_add_ps(sum1_sqr1, _mm256_mul_ps(a0, a0));
    sum1_sqr2 = _mm256_add_ps(sum1_sqr2, _mm256_mul_ps(b0, b0));

    a0 = _mm256_loadu_ps(d1 + i + 2 * step);
    b0 = _mm256_loadu_ps(d2 + i + 2 * step);
    sum2 = _mm256_add_ps(sum2, _mm256_mul_ps(a0, b0));
    sum2_sqr1 = _mm256_add_ps(sum2_sqr1, _mm256_mul_ps(a0, a0));
    sum2_sqr2 = _mm256_add_ps(sum2_sqr2, _mm256_mul_ps(b0, b0));

    a0 = _mm256_loadu_ps(d1 + i + 3 * step);
    b0 = _mm256_loadu_ps(d2 + i + 3 * step);
    sum3 = _mm256_add_ps(sum3, _mm256_mul_ps(a0, b0));
    sum3_sqr1 = _mm256_add_ps(sum3_sqr1, _mm256_mul_ps(a0, a0));
    sum3_sqr2 = _mm256_add_ps(sum3_sqr2, _mm256_mul_ps(b0, b0));
  }
  sum0 = _mm256_add_ps(sum0, sum1);
  sum2 = _mm256_add_ps(sum2, sum3);
  sum0 = _mm256_add_ps(sum0, sum2);
  sum0_sqr1 = _mm256_add_ps(sum0_sqr1, sum1_sqr1);
  sum2_sqr1 = _mm256_add_ps(sum2_sqr1, sum3_sqr1);
  sum0_sqr1 = _mm256_add_ps(sum0_sqr1, sum2_sqr1);
  sum0_sqr2 = _mm256_add_ps(sum0_sqr2, sum1_sqr2);
  sum2_sqr2 = _mm256_add_ps(sum2_sqr2, sum3_sqr2);
  sum0_sqr2 = _mm256_add_ps(sum0_sqr2, sum2_sqr2);
  return reduceSum(sum0) / sqrt(reduceSum(sum0_sqr1)) / sqrt(reduceSum(sum0_sqr2));
}

int jsonInteger(const crow::json::rvalue& v, const string& key)
{
  if (!v.has(key))
    return {};

  if (v[key].t() == crow::json::type::Number || v[key].t() == crow::json::type::String)
    try
    {
      return static_cast<int>(v[key]);
    } catch (...)
    {
      // ничего не делаем
    }

  return {};
}

string getEventInfo(absl::string_view url_template, absl::string_view uuid)
{
  cpr::SslOptions ssl_opts = cpr::Ssl(cpr::ssl::VerifyHost{false}, cpr::ssl::VerifyPeer{false},
    cpr::ssl::VerifyStatus{false}, cpr::ssl::Ciphers{"DEFAULT@SECLEVEL=1"});
  auto url = absl::Substitute(url_template, uuid);
  cpr::Response response = cpr::Get(cpr::Url{url}, ssl_opts);

  if (response.status_code != cpr::status::HTTP_OK)
    return {};

  crow::json::rvalue json = crow::json::load(response.text);
  if (json.error())
    return {};

  if (!json.has("data"))
    return {};

  if (json["data"].t() != crow::json::type::List)
    return {};

  if (json["data"].size() == 0)
    return {};

  auto data = json["data"][0];

  vector<string> info_list;
  if (data.has("mechanizma_description"))
    info_list.push_back(absl::StrCat("объект: ", string(data["mechanizma_description"].s())));
  auto event_type = jsonInteger(data, "event");
  if (event_type > 0 && event_type < EVENT_TYPES.size())
    info_list.push_back(absl::StrCat("тип события: ", std::data(EVENT_TYPES)[event_type]));
  if (event_type == 3 && data.has("detail"))  // открытие ключом
  {
    vector<string> details = absl::StrSplit(string(data["detail"].s()), ':');
    if (!details.empty())
      info_list.push_back(absl::StrCat("ключ: ", details[0]));
  }
  if (data.has("flat_number"))
  {
    if (data["flat_number"].t() != crow::json::type::Null)
    {
      string flat_number = data["flat_number"].s();
      info_list.push_back(absl::StrCat("квартира: ", flat_number));
    }
  }

  return absl::StrJoin(info_list, "; ");
}

void outputAsText(const vector<ResultItem>& items)
{
  for (const auto& item : items)
  {
    cout
      << "event_date: " << item.event_date << "\n"
      << "event_id: " << item.event_id << "\n"
      << "uuid: " << item.uuid << "\n"
      << "url_image: " << item.url_image << "\n"
      << "info: " << item.info << "\n"
      << "id_descriptor: " << item.id_descriptor << "\n"
      << "similarity: " << item.similarity << "\n"
      << "\n";
  }
}

string outputAsJson(const vector<ResultItem>& items)
{
  crow::json::wvalue::list r;
  for (const auto& item : items)
    r.push_back({{"event_date", item.event_date},
      {"event_id", item.event_id},
      {"uuid", item.uuid},
      {"url_image", item.url_image},
      {"info", item.info},
      {"id_descriptor", item.id_descriptor},
      {"similarity", absl::StrCat(item.similarity)}});

  crow::json::wvalue r_json{
    {"result", r}};

  return r_json.dump();
}

string parseDate(absl::string_view s)
{
  if (absl::AsciiStrToLower(s) == DATE_NOW)
    return absl::FormatTime(DATE_FORMAT, absl::Now(), absl::LocalTimeZone());

  if (absl::StartsWith(s, "-"))
  {
    int days{};
    if (absl::SimpleAtoi(s, &days))
    {
      auto d = std::chrono::system_clock::now() + std::chrono::days{days};
      return absl::FormatTime(DATE_FORMAT, absl::FromChrono(d), absl::LocalTimeZone());
    }
  }

  absl::Time t;
  if (absl::ParseTime(DATE_FORMAT, s, &t, nullptr))
    return absl::FormatTime(DATE_FORMAT, t, absl::LocalTimeZone());

  return {};
}

int main(int ac, char* av[])
{
  try
  {
    string config_file = "search_faces.config";
    int id_sgroup = 1;
    double tolerance = 0.5;
    string host_url_prefix = "https://static.dm.lanta.me";
    string url_event_template;
    string frs_logs_url_prefix = "https://faceid.lanta.me/screenshots";
    string output_type = OUTPUT_TYPE_JSON;
    bool flag_events = false;
    bool flag_frs_logs = false;
    bool flag_info = false;
    string param_start_date = "-180";
    string param_end_date = "now";

    po::options_description generic(200);

    // clang-format off
    generic.add_options()
      (absl::StrCat(PARAM_HELP, ",h").c_str(), "Показать список параметров.")
      (absl::StrCat(PARAM_CONFIG, ",c").c_str(), po::value<string>(&config_file)->default_value(config_file), "Файл с конфигом.");
    // clang-format on

    po::options_description config(200);

    // clang-format off
    config.add_options()
      (PARAM_TOLERANCE, po::value<double>(&tolerance)->default_value(tolerance), "Толерантность.")
      (PARAM_GROUP_ID, po::value<int>(&id_sgroup)->default_value(id_sgroup), "Идентификатор специальной группы.")
      (PARAM_OUTPUT_TYPE, po::value<string>(&output_type)->default_value(output_type), "Тип вывода результата поиска (допустимые значения: json, text).")
      (PARAM_EVENTS, po::bool_switch(&flag_events), "Искать в событиях.")
      (PARAM_FRS_LOGS, po::bool_switch(&flag_frs_logs), "Искать в журнале FRS.")
      (PARAM_INFO, po::bool_switch(&flag_info), "Добавить расширенную информацию по событию.")
      (PARAM_START_DATE, po::value<string>(&param_start_date)->default_value(param_start_date), "Задаёт начальную дату и может содержать значение в формате YYYY-MM-DD, отрицательное число (кол-во дней назад от текущей даты) или now (текущая дата).")
      (PARAM_END_DATE, po::value<string>(&param_end_date)->default_value(param_end_date), "Задаёт конечную дату и может содержать значение в формате YYYY-MM-DD, отрицательное число (кол-во дней назад от текущей даты) или now (текущая дата).");
    // clang-format on

    po::options_description cmdline_options("Параметры командной строки");
    cmdline_options.add(generic).add(config);

    po::options_description config_file_options;
    config_file_options.add(config);

    po::variables_map vm;
    store(po::parse_command_line(ac, av, cmdline_options), vm);
    notify(vm);

    if (vm.count(PARAM_HELP))
    {
      cmdline_options.print(cout, 50);
      return 0;
    }

    auto search_start_date = parseDate(param_start_date);
    if (search_start_date.empty())
    {
      cerr << "Неправильно указано значение параметра " << PARAM_START_DATE << ": " << param_start_date << "\n";
      return -1;
    }

    auto search_end_date = parseDate(param_end_date);
    if (search_end_date.empty())
    {
      cerr << "Неправильно указано значение параметра " << PARAM_END_DATE << ": " << param_end_date << "\n";
      return -1;
    }

    if (search_start_date > search_end_date)
    {
      cerr << "Начальная дата поиска не должна превышать конечную.\n";
      return -1;
    }

    boost::property_tree::ptree s_config;
    boost::property_tree::ini_parser::read_ini(config_file, s_config);
    string events_path = s_config.get<string>("common.events_path", "./");
    host_url_prefix = s_config.get<string>("common.host_url_prefix", host_url_prefix);
    url_event_template = s_config.get<string>("common.url_event_template", url_event_template);
    string frs_logs_path = s_config.get<string>("common.frs_logs_path", "./");
    frs_logs_url_prefix = s_config.get<string>("common.frs_logs_url_prefix", host_url_prefix);
    if (vm.count(PARAM_TOLERANCE) == 0)
      tolerance = s_config.get<double>("common.tolerance", tolerance);
    if (vm.count(PARAM_GROUP_ID) == 0)
      id_sgroup = s_config.get<int>("common.group_id", id_sgroup);
    if (vm.count(PARAM_OUTPUT_TYPE) == 0)
      output_type = s_config.get<string>("common.output_type", output_type);
    else
    {
      if (output_type != OUTPUT_TYPE_TEXT && output_type != OUTPUT_TYPE_JSON)
      {
        cerr << "Неправильно указано значение параметра " << PARAM_OUTPUT_TYPE << ": " << output_type << "\n";
        return -1;
      }
    }
    string sql_host = s_config.get<string>("sql.host", "localhost");
    int sql_port = s_config.get<int>("sql.port", 33060);
    string sql_db_name = s_config.get<string>("sql.db_name", "test_frs");
    string sql_user_name = s_config.get<string>("sql.user_name", "user_frs");
    string sql_password = s_config.get<string>("sql.password", "");
    string mysql_settings = sql_user_name + ":" + sql_password + "@" + sql_host + ":" + std::to_string(sql_port) + "/" + sql_db_name;
    auto sql_client = make_unique<mysqlx::Client>(mysql_settings);
    auto mysql_session = sql_client->getSession();
    auto result = mysql_session.sql(SQL_GET_SG_FACE_DESCRIPTORS)
                    .bind(id_sgroup)
                    .execute();
    vector<DescriptorData> descriptors;
    vector<int> id_descriptors;

    auto tt0 = std::chrono::steady_clock::now();

    if (output_type == OUTPUT_TYPE_TEXT)
    {
      cout << "Начальная дата поиска: " << search_start_date << "\n";
      cout << "Конечная дата поиска: " << search_end_date << "\n";
      cout << "Список идентификаторов дескрипторов специальной группы " << id_sgroup << ":\n";
    }
    for (auto row : result)
    {
      int id_descriptor = row[0];
      auto bytes = row[1].getRawBytes();
      descriptors.push_back({});
      id_descriptors.push_back(id_descriptor);
      memcpy(descriptors.back().data, bytes.first, bytes.size());
      if (output_type == OUTPUT_TYPE_TEXT)
        cout << "    " << id_descriptor << "\n";
    }

    if (output_type == OUTPUT_TYPE_TEXT)
      cout << "\n";
    vector<ResultItem> search_result;

    HashSet<string> event_ids;

    if (flag_events)
      for (const auto& dir_entry : std::filesystem::directory_iterator(events_path))
        if (dir_entry.is_regular_file() && dir_entry.path().extension().string() == DATA_FILE_SUFFIX
            && dir_entry.path().filename() >= search_start_date + DATA_FILE_SUFFIX
            && dir_entry.path().filename() <= search_end_date + DATA_FILE_SUFFIX)
        {
          // для теста
          // cout << dir_entry.path().filename().string() << "\n";

          error_code ec;
          const auto f_size = std::filesystem::file_size(dir_entry.path(), ec);
          EventData data{};
          if (!ec && f_size > 0)
          {
            string s_data(f_size, '\0');
            ifstream fr_data(dir_entry.path(), std::ios::in | std::ios::binary);
            while (fr_data.good())
            {
              fr_data.read(reinterpret_cast<char*>(&data), sizeof(data));
              if (fr_data.gcount() == sizeof(data))
              {
                for (int k = 0; k < descriptors.size(); ++k)
                {
                  double cosine_distance = cosineDistanceSIMD(descriptors[k].data, data.data);
                  if (cosine_distance > tolerance)
                  {
                    string event_id = string(data.event_id, sizeof(data.event_id));
                    event_ids.insert(event_id);

                    // открываем json файл с идентификатором события
                    string json_filename = absl::Substitute("$0/$1/$2/$3/$4.json", events_path, event_id[0], event_id[1], event_id[2], event_id);
                    auto json_size = std::filesystem::file_size(json_filename, ec);
                    if (!ec && json_size > 0)
                    {
                      ifstream f_json(json_filename, ios::binary);
                      string json_data(json_size, '\0');
                      f_json.read(json_data.data(), static_cast<streamsize>(json_size));
                      f_json.close();

                      crow::json::rvalue json = crow::json::load(json_data);
                      string uuid = json["event_uuid"].s();
                      string image_url;
                      string info;
                      if (!uuid.empty())
                      {
                        if (absl::StartsWith(uuid, "http"))
                          image_url = uuid;  // uuid содержит URL изображения
                        else                 // URL изображения формируется исходя из uuid
                        {
                          image_url = absl::Substitute("$0/$1/$2/$3/$4/$5/$6.jpg", host_url_prefix,
                            dir_entry.path().filename().stem().string(), uuid[0], uuid[1], uuid[2], uuid[3], uuid);

                          if (flag_info)
                            info = getEventInfo(url_event_template, uuid);
                        }
                      }
                      string event_date = json["event_date"].s();
                      if (event_date.empty())
                        event_date = dir_entry.path().filename().stem().string();

                      search_result.push_back({event_date,
                        event_id,
                        uuid,
                        image_url,
                        info,
                        id_descriptors[k],
                        cosine_distance});
                    }
                  }
                }
              }
            }
          }
        }

    if (flag_frs_logs)
      for (const auto& dir_entry : std::filesystem::recursive_directory_iterator(frs_logs_path))
        if (dir_entry.is_regular_file() && dir_entry.path().extension().string() == DATA_FILE_SUFFIX)
        {
          error_code ec;
          const auto f_size = std::filesystem::file_size(dir_entry.path(), ec);
          EventData data{};
          if (!ec && f_size > 0)
          {
            string s_data(f_size, '\0');
            ifstream fr_data(dir_entry.path(), std::ios::in | std::ios::binary);
            while (fr_data.good())
            {
              fr_data.read(reinterpret_cast<char*>(&data), sizeof(data));
              if (fr_data.gcount() == sizeof(data))
              {
                for (int k = 0; k < descriptors.size(); ++k)
                {
                  double cosine_distance = cosineDistanceSIMD(descriptors[k].data, data.data);
                  if (cosine_distance > tolerance)
                  {
                    string event_id = string(data.event_id, sizeof(data.event_id));

                    // если запись журнала FRS попала в события dm, то игнорируем её
                    if (event_ids.find(event_id) != event_ids.end())
                      continue;

                    // открываем json файл журнала
                    string f_name = dir_entry.path().stem();
                    string json_filename = dir_entry.path().parent_path() / (f_name + ".json");
                    auto json_size = std::filesystem::file_size(json_filename, ec);
                    if (!ec && json_size > 0)
                    {
                      ifstream f_json(json_filename, ios::binary);
                      string json_data(json_size, '\0');
                      f_json.read(json_data.data(), static_cast<streamsize>(json_size));
                      f_json.close();

                      crow::json::rvalue json = crow::json::load(json_data);
                      string image_url = absl::Substitute("$0/$1/$2/$3/$4.jpg", frs_logs_url_prefix,
                        f_name[0], f_name[1], f_name[2], f_name);

                      const auto ft = filesystem::last_write_time(dir_entry.path(), ec);
                      const auto tt = std::chrono::file_clock::to_sys(ft);
                      DateTime dt = absl::FromUnixNanos(static_cast<int64_t>(tt.time_since_epoch().count()));
                      string event_date = absl::FormatTime(EVENT_DATE_FORMAT, dt, absl::LocalTimeZone());

                      search_result.push_back({event_date,
                        event_id,
                        "",
                        image_url,
                        "",
                        id_descriptors[k],
                        cosine_distance});
                    }
                  }
                }
              }
            }
          }
        }

    sort(search_result.begin(), search_result.end(), greater());

    auto tt1 = std::chrono::steady_clock::now();
    if (output_type == OUTPUT_TYPE_TEXT)
    {
      cout << "Результат поиска:\n\n";
      outputAsText(search_result);
      cout << "Время поиска: " << std::chrono::duration<double, std::milli>(tt1 - tt0).count() << " мс\n\n";
    } else if (output_type == OUTPUT_TYPE_JSON)
      cout << outputAsJson(search_result) << "\n";

  } catch (const exception& e)
  {
    cerr << e.what() << "\n";
    return -1;
  }

  return 0;
}
