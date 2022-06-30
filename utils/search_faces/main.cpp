#include <absl/strings/match.h>
#include <absl/strings/substitute.h>
#include <chrono>
#include <cstdint>
#include <filesystem>
#include <iostream>

#include <boost/program_options.hpp>
#include <boost/property_tree/ini_parser.hpp>
#include <boost/property_tree/ptree.hpp>

#include "absl/container/flat_hash_map.h"
#include "absl/container/flat_hash_set.h"
#include "absl/time/time.h"
#include "crow/json.h"
#include "mysqlx/xdevapi.h"

using namespace std;
namespace po = boost::program_options;

using DateTime = absl::Time;

template <typename T>
using HashSet = absl::flat_hash_set<T>;

const int DESCRIPTOR_SIZE = 512;
typedef float Data[DESCRIPTOR_SIZE];

//бинарные данные события для хранения и дальнейшего применения
struct EventData
{
  char event_id[32];  //внутренний идентификатор события
  int32_t position;   //позиция дескриптора (нумерация начинается с нуля)
  Data data;          //данные дескриптора (вектора)
} __attribute__((packed));

struct DescriptorData
{
  Data data;  //данные дескриптора (вектора)
} __attribute__((packed));

struct ResultItem
{
  string event_date;
  string event_id;  //идентификатор из журнала FRS (имя файла со скриншотом без расширения)
  string uuid;      //идентификатор события dm
  string url_image;
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
    ldsg.id_sgroup = ?
 )_SQL_";

double cosineDistance(const Data& d1, const Data& d2)
{
  double r = 0.0;
  double n1 = 0.0;
  double n2 = 0.0;
  for (size_t i = 0; i < DESCRIPTOR_SIZE; ++i)
  {
    r += d1[i] * d2[i];
    n1 += d1[i] * d1[i];
    n2 += d2[i] * d2[i];
  }
  if (n1 > 0 && n2 > 0)
    return r / sqrt(n1) / sqrt(n2);

  return -1.0;
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
      {"id_descriptor", item.id_descriptor},
      {"similarity", item.similarity}});

  crow::json::wvalue r_json{
    {"result", r}};

  return r_json.dump();
}

int main(int ac, char* av[])
{
  try
  {
    string config_file = "search_faces.config";
    int id_sgroup = 1;
    double tolerance = 0.5;
    string host_url_prefix = "https://static.dm.lanta.me";
    string frs_logs_url_prefix = "https://faceid.lanta.me/screenshots";
    string output_type = "json";
    bool flag_events = false;
    bool flag_frs_logs = false;

    po::options_description generic;
    generic.add_options()("help", "Показать список параметров.")("config,c", po::value<string>(&config_file)->default_value(config_file), "Файл с конфигурацией.");

    po::options_description config("Основные параметры");
    config.add_options()("tolerance", po::value<double>(&tolerance), "Толерантность.")("group_id", po::value<int>(&id_sgroup), "Идентификатор специальной группы.")("output_type", po::value<string>(&output_type), "Тип вывода результатa поиска (допустимые значения: json, text).")("events", po::bool_switch(&flag_events), "Искать в событиях.")("frs_logs", po::bool_switch(&flag_frs_logs), "Искать в журнале FRS.");

    po::options_description cmdline_options;
    cmdline_options.add(generic).add(config);

    po::options_description config_file_options;
    config_file_options.add(config);

    po::variables_map vm;
    store(po::parse_command_line(ac, av, cmdline_options), vm);
    notify(vm);

    if (vm.count("help"))
    {
      cout << cmdline_options << "\n";
      return 0;
    }

    boost::property_tree::ptree s_config;
    boost::property_tree::ini_parser::read_ini(config_file, s_config);
    string events_path = s_config.get<string>("common.events_path", "./");
    host_url_prefix = s_config.get<string>("common.host_url_prefix", host_url_prefix);
    string frs_logs_path = s_config.get<string>("common.frs_logs_path", "./");
    frs_logs_url_prefix = s_config.get<string>("common.frs_logs_url_prefix", host_url_prefix);
    if (vm.count("tolerance") == 0)
      tolerance = s_config.get<double>("common.tolerance", tolerance);
    if (vm.count("group_id") == 0)
      id_sgroup = s_config.get<int>("common.group_id", id_sgroup);
    if (vm.count("output_type") == 0)
      output_type = s_config.get<string>("common.output_type", output_type);
    else
    {
      if (output_type != "text" && output_type != "json")
      {
        cerr << "Неправильно указано значение параметра output_type.\n";
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

    if (output_type == "text")
      cout << "Список идентификаторов дескрипторов специальной группы " << id_sgroup << ":\n";
    for (auto row : result)
    {
      int id_descriptor = row[0];
      auto bytes = row[1].getRawBytes();
      descriptors.push_back({});
      id_descriptors.push_back(id_descriptor);
      memcpy(descriptors.back().data, bytes.first, bytes.size());
      if (output_type == "text")
        cout << "    " << id_descriptor << "\n";
    }

    if (output_type == "text")
      cout << "\n";
    vector<ResultItem> search_result;

    HashSet<string> event_ids;

    if (flag_events)
      for (const auto& dir_entry : std::filesystem::directory_iterator(events_path))
        if (dir_entry.is_regular_file() && dir_entry.path().extension().string() == ".dat")
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
                  double cosine_distance = cosineDistance(descriptors[k].data, data.data);
                  if (cosine_distance > tolerance)
                  {
                    string event_id = string(data.event_id, sizeof(data.event_id));
                    event_ids.insert(event_id);

                    //открываем json файл с идентификатором события
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
                      if (!uuid.empty())
                      {
                        if (absl::StartsWith(uuid, "http"))
                          image_url = uuid;  // uuid содержит URL изображения
                        else                 // URL изображения формируется исходя из uuid
                          image_url = absl::Substitute("$0/$1/$2/$3/$4/$5/$6.jpg", host_url_prefix,
                            dir_entry.path().filename().stem().string(), uuid[0], uuid[1], uuid[2], uuid[3], uuid);
                      }
                      string event_date = json["event_date"].s();
                      if (event_date.empty())
                        event_date = dir_entry.path().filename().stem().string();

                      search_result.push_back({event_date,
                        event_id,
                        uuid,
                        image_url,
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
        if (dir_entry.is_regular_file() && dir_entry.path().extension().string() == ".dat")
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
                  double cosine_distance = cosineDistance(descriptors[k].data, data.data);
                  if (cosine_distance > tolerance)
                  {
                    string event_id = string(data.event_id, sizeof(data.event_id));

                    //если запись журнала FRS попала в события dm, то игнорируем её
                    if (event_ids.find(event_id) != event_ids.end())
                      continue;

                    //открываем json файл журнала
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
                      string event_date = absl::FormatTime("%Y-%m-%d %H:%M:%S", dt, absl::LocalTimeZone());

                      search_result.push_back({event_date,
                        event_id,
                        "",
                        image_url,
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
    if (output_type == "text")
      cout << "Время поиска: " << std::chrono::duration<double, std::milli>(tt1 - tt0).count() << " мс\n\n";

    if (output_type == "text")
    {
      cout << "Результат поиска:\n\n";
      outputAsText(search_result);
    } else if (output_type == "json")
      cout << outputAsJson(search_result) << "\n";

  } catch (const exception& e)
  {
    cerr << e.what() << "\n";
    return -1;
  }

  return 0;
}
