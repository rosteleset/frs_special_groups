import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:html' as html;
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:get_storage/get_storage.dart';

const appTitle = 'Специальная группа';
const imageWidth = 200.0;
const imageHeight = 200.0;
const imageDialogWidth = 300.0;
const imageDialogHeight = 300.0;
const searchFaceHeight = 720.0;
const faceCardHeight = 448.0;

var sgGroupName = '';
const sgApiBaseUrl = '/sg/';

const sgApiLogin = sgApiBaseUrl + "login.php";
const sgApiListFaces = sgApiBaseUrl + 'list_faces.php';
const sgApiRegisterFace = sgApiBaseUrl + 'register_face.php';
const sgApiDeleteFaces = sgApiBaseUrl + 'delete_faces.php';
const sgApiSearchFaces = sgApiBaseUrl + 'search_faces.php';
const sgApiSendTelegram = sgApiBaseUrl + 'send_telegram.php';
const sgApiGetPeopleInfo = sgApiBaseUrl + 'get_people_info.php';
const sgApiUpdatePersonInfo = sgApiBaseUrl + 'update_person_info.php';
const sgApiGetUsers = sgApiBaseUrl + 'get_users.php';

const dialogResultCancel = 0;
const dialogResultOk = 1;
const dialogResultYes = 2;
const dialogResultNo = 3;

String login = '';
String password = '';
bool rememberMe = true;
bool isLoggedIn = false;
bool forceLogin = false;
const String keyLogin = 'login';
const String keyPassword = 'password';
const String keyRememberMe = 'rememberMe';
const String keyForceLogin = 'forceLogin';

class MouseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class Face {
  final int faceId;
  final String faceImage;

  const Face({
    required this.faceId,
    required this.faceImage,
  });

  factory Face.fromJson(Map<String, dynamic> json) {
    return Face(
      faceId: json['faceId'],
      faceImage: json['faceImage'],
    );
  }
}

Future<bool> doLogin(String loginUser, String passwordUser) async {
  try {
    developer.log('doLogin login:password = $loginUser:$passwordUser');
    final response = await http.post(Uri.parse(sgApiLogin),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
        }, body: jsonEncode(<String, dynamic> {
          'login': loginUser,
          'password': passwordUser,
        }));
    if (response.statusCode == 200) {
      login = loginUser;
      password = passwordUser;
      var json = jsonDecode(response.body);
      sgGroupName = json['groupName'];
      return true;
    }
  } on Exception catch(e) {
    developer.log(e.toString());
  }

  return false;
}

Future<List<Face>> getFaces() async {
  developer.log(sgApiListFaces);
  try {
    final response = await http
        .post(Uri.parse(sgApiListFaces),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode(<String, dynamic> {
          'login': login,
          'password': password,
        })
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['data'] as List).map((e) => Face.fromJson(e)).toList();
    } else {
      throw Exception('Ошибка при вызове $sgApiListFaces');
    }
  } on Exception catch(e) {
    developer.log(e.toString());
  }
  return [];
}

int getFaceIndex(List<Face> list, int faceId) {
  for (int i = 0; i < list.length; ++i) {
    if (list[i].faceId == faceId) {
      return i;
    }
  }

  return -1;
}

class SearchFace {
  final String uuid;
  final int faceId;
  final String urlImage;
  final String eventDate;
  final double similarity;

  const SearchFace({
    required this.uuid,
    required this.faceId,
    required this.urlImage,
    required this.eventDate,
    required this.similarity
  });

  factory SearchFace.fromJson(Map<String, dynamic> json) {
    return SearchFace(
      uuid: json['uuid'],
      faceId: json['id_descriptor'],
      urlImage: json['url_image'],
      eventDate: json['event_date'],
      similarity: json['similarity']
    );
  }
}

class PersonInfo {
  final int faceId;
  final String info;

  const PersonInfo({
    required this.faceId,
    required this.info
  });

  factory PersonInfo.fromJson(Map<String, dynamic> json) {
    return PersonInfo(
        faceId: json['faceId'],
        info: json['info']
    );
  }
}

class SgApp extends StatelessWidget {
  const SgApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: MouseScrollBehavior(),
      title: appTitle,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SgHomePage(title: appTitle),
    );
  }
}

class SgHomePage extends StatefulWidget {
  const SgHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<SgHomePage> createState() => _SgHomePageState();
}

class _SgHomePageState extends State<SgHomePage> {
  late Future<List<Face>> _futureFaces;
  final HashMap<int, String> _peopleInfo = HashMap();
  List<SearchFace> _searchFaces = [];
  bool _searchFacesInProgress = false;
  bool _loginFailed = false;
  bool _rememberMe = rememberMe;
  bool _forceLogin = forceLogin;
  final Set<int> _excludedFaces = {};
  double _currentSimilarity = 0.55;

  final _loginTextController = TextEditingController(text: login);
  final _passwordTextController = TextEditingController(text: password);
  final _personInfoController = TextEditingController();

  Future<List<Face>> _emptyFacesList() async {
    return [];
  }

  @override
  void initState() {
    super.initState();
    _futureFaces = isLoggedIn ? getFaces() : _emptyFacesList();
    if (isLoggedIn) {
      callApiGetPeopleInfo();
    } else {
      _peopleInfo.clear();
    }
  }

  Future<int> callApiSearchFaces() async {
    int result = 400;
    setState(() {
      _searchFacesInProgress = true;
    });
    try {
      final response = await http
        .post(Uri.parse(sgApiSearchFaces),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(<String, dynamic> {
            'login': login,
            'password': password,
            'similarity': _currentSimilarity
          })
      );

      if (response.statusCode == 200) {
        setState(() {
          _searchFaces = (jsonDecode(response.body)['result'] as List).map((e) => SearchFace.fromJson(e)).toList();
          developer.log("search result length: ${_searchFaces.length}");
          _searchFacesInProgress = false;
        });

        return 200;
      }

      if (response.statusCode == 204) {
        setState(() {
          _searchFacesInProgress = false;
        });

        return 204;
      }

      result = response.statusCode;
      developer.log("response code: $result");
    } on Exception catch(e) {
      developer.log(e.toString());
    }

    setState(() {
      _searchFaces.clear();
      _searchFacesInProgress = false;
    });

    return result;
  }

  Future<int> callApiUpdatePersonInfo(int faceId, String info) async {
    int result = 400;
    try {
      final response = await http
          .post(Uri.parse(sgApiUpdatePersonInfo),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(<String, dynamic> {
            'login': login,
            'password': password,
            'faceId': faceId,
            'info': info,
          })
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _peopleInfo[faceId] = info;
        });

        return 200;
      }
    } on Exception catch(e) {
      developer.log(e.toString());
    }

    return result;
  }

  Future<int> callApiGetPeopleInfo() async {
    int result = 400;
    try {
      final response = await http
          .post(Uri.parse(sgApiGetPeopleInfo),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(<String, dynamic> {
            'login': login,
            'password': password,
          })
      );

      if (response.statusCode == 200) {
        setState(() {
          _peopleInfo.clear();
          for (var element in (jsonDecode(response.body) as List)) {
            var personInfo = PersonInfo.fromJson(element);
            _peopleInfo[personInfo.faceId] = personInfo.info;
          }
        });

        return 200;
      }

      if (response.statusCode == 204) {
        setState(() {
          _peopleInfo.clear();
        });

        return 204;
      }

      result = response.statusCode;
      developer.log("response code: $result");
    } on Exception catch(e) {
      developer.log(e.toString());
    }

    setState(() {
      _peopleInfo.clear();
    });

    return result;
  }

  void callApiSendTelegram(SearchFace item) async {
    try {
      final response = await http
          .post(Uri.parse(sgApiSendTelegram), headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      }, body: jsonEncode(<String, dynamic>{
        'login': login,
        'password': password,
        'screenshot': item.urlImage,
        'date': item.eventDate,
        'faceId': item.faceId
      }));
      if (response.statusCode != 200) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            content: const Text('Не удалось отправить сообщение в канал Telegram.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      }
    } on Exception catch(e) {
      developer.log(e.toString());
    }
  }

  Future<int?> dialogDeletePhoto(String url) {
    return showDialog<int?>(context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Удалить фотографию?'),
          content: Image(
            image: NetworkImage(url),
            width: imageDialogWidth,
            height: imageDialogHeight,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, dialogResultYes),
              child: const Text('Да'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, dialogResultNo),
              child: const Text('Нет'),
            ),
          ],
        )
    );
  }

  Future<int?> dialogUpdatePersonInfo(int faceId, String info) {
    _personInfoController.text = info;
    return showDialog<int?>(context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Дополнительная информация'),
        content: TextField(
          autofocus: true,
          controller: _personInfoController,
          maxLength: 250,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, dialogResultOk),
            child: const Text('Ok'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, dialogResultCancel),
            child: const Text('Отменить'),
          ),
        ],
      )
    );
  }

  Future showRegisteredPhoto(String url) {
    return showDialog(context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Фотография зарегистрирована'),
          content: Image(
            image: NetworkImage(url),
            width: imageDialogWidth,
            height: imageDialogHeight,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        )
    );
  }

  void openFileDialog() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
        ],
        withData: true,
        allowMultiple: false,
        dialogTitle: 'Выберите фотографию'
    );
    try {
      if (result != null && result.files.isNotEmpty) {
        developer.log(
            "Extension: " + (result.files.first.extension ?? '<empty>') +
                ";  size: " +
                (result.files.first.bytes?.length.toString() ?? '<empty>'));
        if (result.files.first.bytes?.isNotEmpty == true) {
          var extension = result.files.first.extension!;
          if (extension == "jpg") {
            extension = "jpeg";
          }
          final imageEncoded = base64.encode(result.files.first.bytes!);
          final response = await http
              .post(Uri.parse(sgApiRegisterFace),
              headers: {
                HttpHeaders.contentTypeHeader: 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'login': login,
                'password': password,
                'url': 'data:image/$extension;base64,' + imageEncoded,
              })
          );
          if (response.statusCode == 200) {
            setState(() {
              _futureFaces = getFaces();
            });
            var url = Face
                .fromJson(jsonDecode(response.body)['data'])
                .faceImage;
            await showRegisteredPhoto(url);
          } else {
            showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                content: Text(jsonDecode(utf8.decode(response.bodyBytes))['message']),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } on Exception catch(e) {
      developer.log(e.toString());
    }
  }

  void deletePhotoDialog(BuildContext context, String url, int faceId) async {
    try {
      developer.log("Delete photo: $url");
      var r = await dialogDeletePhoto(url);
      if (r == dialogResultYes) {
        var faces = List.empty(growable: true);
        faces.add(faceId);
        final response = await http
            .post(Uri.parse(sgApiDeleteFaces),
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(<String, dynamic> {
              'login': login,
              'password': password,
              'faces': faces,
            })
        );
        if (response.statusCode == 200 || response.statusCode == 204) {
          setState(() {
            _futureFaces = getFaces();
            _peopleInfo.remove(faceId);
          });
        } else {
          throw Exception('Ошибка при вызове $sgApiDeleteFaces');
        }
      }
    } on Exception catch(e) {
      developer.log(e.toString());
    }
  }

  void updatePersonInfoDialog(BuildContext context, int faceId, String info) async {
    try {
      developer.log("Update person info: $faceId; $info");
      var r = await dialogUpdatePersonInfo(faceId, info);
      if (r == dialogResultOk) {
        developer.log(_personInfoController.text);
        callApiUpdatePersonInfo(faceId, _personInfoController.text);
      }
    } on Exception catch(e) {
      developer.log(e.toString());
    }
  }

  void callApiLogin(String loginUser, String passwordUser) async {
    if (await doLogin(loginUser, passwordUser)) {
      login = loginUser;
      password = passwordUser;
      forceLogin = false;
      GetStorage().write(keyForceLogin, forceLogin);
      if (rememberMe) {
        GetStorage().write(keyLogin, login);
        GetStorage().write(keyPassword, password);
      } else {
        GetStorage().remove(keyLogin);
        GetStorage().remove(keyPassword);
      }
      setState(() {
        isLoggedIn = true;
        _forceLogin = forceLogin;
        _futureFaces = getFaces();
        callApiGetPeopleInfo();
      });
    } else {
      setState(() {
        _loginFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    final ButtonStyle redButtonStyle = ElevatedButton.styleFrom(
      onPrimary: Colors.white,
      primary: Colors.red,
      minimumSize: const Size(88, 36),
      padding: const EdgeInsets.all(16),
      textStyle: const TextStyle(fontSize: 20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    );

    final ButtonStyle greenButtonStyle = ElevatedButton.styleFrom(
      onPrimary: Colors.white,
      primary: Colors.green,
      minimumSize: const Size(88, 36),
      padding: const EdgeInsets.all(16),
      textStyle: const TextStyle(fontSize: 20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    );

    final ButtonStyle blueButtonStyle = ElevatedButton.styleFrom(
      onPrimary: Colors.white,
      primary: Colors.blueAccent,
      minimumSize: const Size(88, 36),
      padding: const EdgeInsets.all(16),
      textStyle: const TextStyle(fontSize: 20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    );

    var facesWidget = FutureBuilder<List<Face>>(
      future: _futureFaces,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              return Card(
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(snapshot.data![index].faceId.toString()),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.create),
                            tooltip: "Изменить дополнительную информацию",
                            onPressed: () {
                              _peopleInfo.putIfAbsent(snapshot.data![index].faceId, () => "");
                              updatePersonInfoDialog(context, snapshot.data![index].faceId, _peopleInfo[snapshot.data![index].faceId]!);
                            },
                          ),
                          if (_peopleInfo.containsKey(snapshot.data![index].faceId) && _peopleInfo[snapshot.data![index].faceId]!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(_peopleInfo[snapshot.data![index].faceId]!),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("Нет информации",
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Image(
                        image: NetworkImage(snapshot.data![index].faceImage),
                        width: imageWidth,
                        height: imageHeight,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          style: redButtonStyle,
                          onPressed: () {
                            deletePhotoDialog(context, snapshot.data![index].faceImage, snapshot.data![index].faceId);
                          },
                          child: Row(
                              children: const [
                                Icon(Icons.no_photography),
                                SizedBox(width: 8,),
                                Text('Удалить'),
                              ]
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Checkbox(
                          value: !_excludedFaces.contains(snapshot.data![index].faceId),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _excludedFaces.remove(snapshot.data![index].faceId);
                              } else {
                                _excludedFaces.add(snapshot.data![index].faceId);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        } else if (snapshot.hasError) {
          return Text("${snapshot.error}");
        }

        return const CircularProgressIndicator();
      },
    );

    FutureBuilder<List<Face>> faceImage(int faceId) {
      return FutureBuilder(
        future: _futureFaces,
        builder: (context, snapshot) {
          int faceIndex = -1;
          if (snapshot.hasData) {
            faceIndex = getFaceIndex(snapshot.data!, faceId);
          }
          if (faceIndex >= 0) {
            return Image.network(
              snapshot.data![faceIndex].faceImage,
              width: imageWidth,
              height: imageHeight,
            );
          }

          return const Text('-');
        },
      );
    }

    FutureBuilder<List<Face>> deselectAll() {
      return FutureBuilder(
        future: _futureFaces,
        builder: (context, snapshot) {
          return ElevatedButton(
            style: blueButtonStyle,
            onPressed: () {
              if (snapshot.hasData) {
                setState(() {
                  for (var element in snapshot.data!) {
                    _excludedFaces.add(element.faceId);
                  }
                });
              }
            },
            child: Row(
              children: const [
                Icon(Icons.check_box_outline_blank),
                SizedBox(width: 4,),
                Text('Снять пометку со всех'),
              ],
            ),
          );
        });
    }

    Widget showMainUI() {
      return TabBarView(
        children: [
          const Center(
            child: Text(
              "Пользователи (раздел не готов)",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      style: greenButtonStyle,
                      onPressed: _searchFacesInProgress ? null : openFileDialog,
                      child: Row(
                          children: const [
                            Icon(Icons.add_a_photo),
                            SizedBox(width: 8,),
                            Text('Добавить фото...'),
                          ]
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: faceCardHeight,
                      child: Center(
                        child: facesWidget,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      style: blueButtonStyle,
                      onPressed: () {
                        setState(() {
                          _excludedFaces.clear();
                        });
                      },
                      child: Row(
                        children: const [
                          Icon(Icons.done_all),
                          SizedBox(width: 4,),
                          Text('Пометить все'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    deselectAll(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.help,
                        color: Colors.blue,
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          content: const Text('Параметр сходства определяет степень уверенности системы в том,\n'
                              'что лицо в кадре похоже на зарегистрированную фотографию. Чем выше это значение,\n'
                              'тем точнее результат поиска, но тем меньше кадров будет вам показано.\n'
                              'Значение задаётся в диапазоне от 0,4 до 1. По умолчанию используется значение 0,55.'
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Закрыть'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      'Сходство: ${_currentSimilarity.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Slider(
                      min: 0.4,
                      max: 1.0,
                      divisions: 60,
                      label: _currentSimilarity.toStringAsFixed(2),
                      value: _currentSimilarity,
                      onChanged: (double value) {
                        setState(() {
                          _currentSimilarity = value;
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Поиск людей по зарегистрированным фотографиям',
                      child: ElevatedButton(
                        style: blueButtonStyle,
                        onPressed: _searchFacesInProgress ? null : () async {
                          var r = await callApiSearchFaces();
                          if (r == 204) {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                content: const Text('Пожалуйста, сделайте поиск позднее.'
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Закрыть'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.search),
                            SizedBox(width: 4,),
                            Text('Поиск'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_searchFacesInProgress) ...[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Производится поиск...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
              if (!_searchFacesInProgress && _searchFaces.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Результаты поиска',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                for (var item in _searchFaces)
                  if (!_excludedFaces.contains(item.faceId)) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(item.faceId.toString()),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: faceImage(item.faceId),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Дата: ${item.eventDate}',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (item.uuid.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'uuid: ${item.uuid}',
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: item.uuid));
                                        },
                                        icon: const Icon(Icons.copy)
                                    ),
                                  ],
                                ),
                              ],
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Сходство: ${item.similarity}',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () {
                                callApiSendTelegram(item);
                              },
                              icon: const Icon(IconData(0xf0586, fontFamily: 'MaterialIcons')),
                              color: Colors.blue,
                              tooltip: "Отправить в канал Telegram",
                            ),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: item.urlImage));
                              },
                              icon: const Icon(Icons.copy),
                              tooltip: "Скопировать ссылку кадра",
                            ),
                          ],
                        ),
                        Expanded(
                          flex: 2,
                          child: Wrap(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: InkWell(
                                  child: Image.network(
                                    item.urlImage,
                                    //height: searchFaceHeight,
                                    alignment: Alignment.centerLeft,
                                    //fit: BoxFit.fitHeight,
                                  ),
                                  onTap: () {
                                    html.window.open(item.urlImage, '_blank');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
              ],
            ],
          ),
        ],
      );
    }

    Widget showLoginUI() {
      return Center(
        child: SizedBox(
          width: 400,
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Вход в систему',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    onChanged: (_) {
                      if (_loginFailed) {
                        setState(() {
                          _loginFailed = false;
                        });
                      }
                    },
                    controller: _loginTextController,
                    decoration: const InputDecoration(hintText: 'Имя пользователя'),
                    autofillHints: const [AutofillHints.username],
                    autofocus: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    onChanged: (_) {
                      if (_loginFailed) {
                        setState(() {
                          _loginFailed = false;
                        });
                      }
                    },
                    controller: _passwordTextController,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'Пароль'),
                    autofillHints: const [AutofillHints.password],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Запомнить меня"),
                    onChanged: (bool? value) {
                      rememberMe = (value == true);
                      GetStorage().write(keyRememberMe, rememberMe);
                      setState(() {
                        _rememberMe = rememberMe;
                      });
                    },
                    value: _rememberMe,
                  )
                ),
                if (_loginFailed) ...[
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Неправильное имя пользователя или пароль',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    style: blueButtonStyle,
                    onPressed: () {
                      callApiLogin(_loginTextController.text, _passwordTextController.text);
                    },
                    child: const Text('Войти'),
                  )
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
        initialIndex: 1,
        length: 2,
        child: Scaffold(
          appBar: isLoggedIn && !_forceLogin ? AppBar(
            title: Text(sgGroupName),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'Выйти из системы',
                onPressed: () {
                  isLoggedIn = false;
                  forceLogin = true;
                  GetStorage().write(keyForceLogin, forceLogin);
                  setState(() {
                    if (!rememberMe) {
                      login = '';
                      password = '';
                      _loginTextController.text = login;
                      _passwordTextController.text = password;
                    }
                    _forceLogin = forceLogin;
                    _futureFaces = _emptyFacesList();
                    _searchFaces.clear();
                    _peopleInfo.clear();
                    _searchFacesInProgress = false;
                    _excludedFaces.clear();
                    _currentSimilarity = 0.55;
                    _loginFailed = false;
                  });
                },
              )
            ],
            bottom: isLoggedIn && !_forceLogin ? TabBar(
              tabs: [
                Row(
                  children: const [
                    Expanded(child:
                      Tooltip(
                        message: 'Пользователи',
                        child: Tab(
                          icon: Icon(Icons.people_sharp),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: const [
                    Expanded(
                      child: Tooltip(
                        message: 'Поиск людей',
                        child: Tab(
                          icon: Icon(IconData(0xe49c, fontFamily: 'MaterialIcons')),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ) : null,
          ) : null,
          body: isLoggedIn && !_forceLogin ? showMainUI() : showLoginUI(),
        )
    );
  }
}

void main() async {
  await GetStorage.init();
  login = GetStorage().read(keyLogin) ?? login;
  password = GetStorage().read(keyPassword) ?? password;
  rememberMe = GetStorage().read(keyRememberMe) ?? rememberMe;
  forceLogin = GetStorage().read(keyForceLogin) ?? forceLogin;
  developer.log('login:password = $login:$password');

  if (rememberMe && !forceLogin) {
    isLoggedIn = await doLogin(login, password);
  }
  runApp(const SgApp());
}
