import 'package:flutter/material.dart';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';

String appver = "v0.4.ALPHA";

String _selectRandomGreet(int language) {
  List<String> bosnianGreets = [
    "tražiš nešto?",
    "možda da nađeš onu igru što si kao mali volio?",
    "sve se može naći.",
    "sve je tu kad ga ja nađem.",
    "mislio si da je potražiš, a?",
    "hoćemo početi?",
    "vratimo je.",
    "da sam na tvom mjestu, i ja bi je ovdje tražio.",
    "daj da vidim. samo reci šta da tražim.",
    "spor ali precizan.",
    "šta čekaš? piši.",
    "a nema te vala odavno."
  ];

  List<String> englishGreets = [
    "looking for something?",
    "maybe find that one game you loved as a kid?",
    "nothing is hidden.",
    "everything is right there when I find it.",
    "been thinking about finding it, didn't you?",
    "wanna start looking?",
    "let's resurrect together.",
    "if I were you, I'd still use my amazing self.",
    "let me talk to them. I speak their tongue.",
    "the website whisperer... is not my nickname.",
    "life's getting busy, huh?"
  ];

  final random = Random();
  switch (language) {
    case 1: // bos
      return bosnianGreets[random.nextInt(bosnianGreets.length)];
    case _: // eng
      return englishGreets[random.nextInt(englishGreets.length)];
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'necromancer',
      theme: ThemeData(
        fontFamily: "Anonymous",
        brightness: Brightness.dark,
        primaryColor: const Color.fromARGB(255, 67, 67, 67),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color.fromARGB(255, 78, 78, 78),
          onPrimary: Colors.black,
          secondary: Color.fromARGB(255, 131, 131, 131),
          onSecondary: Colors.black,
          error: Color(0xFFCF6679),
          onError: Colors.black,
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color.fromARGB(255, 48, 48, 48),
          foregroundColor: Colors.white,
        ),
      ),
      home: HomePage(title: "necromancer"),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _MyHomePageState();
}

class HomeContent extends StatefulWidget {
  final int lang;
  final String greet;
  final int settings_maxNumResults;
  final bool settings_showArchiveResults;
  const HomeContent({
    super.key,
    required this.lang,
    required this.greet,
    required this.settings_maxNumResults,
    required this.settings_showArchiveResults,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  late final TextEditingController _searchController;

  List<String> logs = [];
  bool showLogs = false;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> performSearch(String query) async {
    if (query.isEmpty) {
      return {
        'error': 'submitted query is empty'
      };
    }

    final url = Uri.https('necro.absnull.xyz', '/search', {
      'q': query,
      'max': widget.settings_maxNumResults.toString(),
      'archive': widget.settings_showArchiveResults ? 'true' : 'false'
    });

    final request = http.Request('GET', url);
    final response = await request.send();

    if (response.statusCode != 200) {
      return {
        'error': 'server returned response ${response.statusCode}'
      };
    }

    List<Map<String, dynamic>>? finalResult;

    await for (final chunk in response.stream.transform(utf8.decoder).transform(LineSplitter())) {
      final line = chunk.trim();
      if (line.isEmpty || !line.startsWith('data:')) continue;

      final dataStr = line.substring(5).trim();
      if (dataStr == '[DONE]' || dataStr.isEmpty) continue;

      try {
        final json = jsonDecode(dataStr) as Map<String, dynamic>;

        if (json.containsKey('log')) {
          final logLine = json['log'] as String;
          setState(() => logs.add(logLine));
          
        }

        if (json['status'] == 'completed') {
          if (json.containsKey('results')) {
            finalResult = (json['results'] as List).cast<Map<String, dynamic>>();
          }
        }
      }
      catch (e) {
        logs.add("! clienterror: $e");
      }
    }
    if (finalResult == null || finalResult.isEmpty) {
      return {
        'error': 'server returned no results.'
      };
    }

    return {
      'results': finalResult
    };
  }

  Future<void> handleSearch(BuildContext context) async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang != 1 ? "first type what you want to search." : "prvo upiši šta hoćeš da tražiš."))
      );
      return;
    }

    setState(() {showLogs = true; isSearching = true;});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.lang != 1 ? "pulling apps out of their graves..." : "izvlačim aplikacije iz groba...")));

    final responsedata = await performSearch(query);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (!context.mounted) return;

    setState(() {
      isSearching = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsContent(lang: widget.lang, response: responsedata)
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/standingnecro.png", width: 300, height: 300,),
            SizedBox(height: 20),
            Text(widget.greet,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center
            ),
            if (!isSearching) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.lang != 1 ? "what are we resurrecting today?" : "šta to danas vraćamo?",
                  suffixIcon: IconButton(
                    onPressed: () => handleSearch(context),
                    icon: Icon(Icons.search)
                  ),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[900]
                ),
                onSubmitted: (_) => handleSearch(context),
              ),
            ),
            if (showLogs)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!)
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    logs.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.4
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
    );
  }
}

class ResultsContent extends StatelessWidget {
  final int lang;
  final Map<String, dynamic> response;

  const ResultsContent({super.key, required this.lang, required this.response});

  @override
  Widget build(BuildContext context) {
    final String? error = response["error"] as String?;
    final List<dynamic>? rawResults = response["results"] as List<dynamic>?;

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            "error: $error",
            style: const TextStyle(color: Colors.red, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (rawResults == null || rawResults.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            lang != 1 ? "no results found." : "nema rezultata.",
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      );
    }

    // Cast once to proper type
    final List<Map<String, dynamic>> results = rawResults
        .cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(
        title: Text(lang != 1 
            ? "found ${results.length} results" 
            : "nađeno ${results.length} rezultata"),
        backgroundColor: Colors.grey[900],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final app = results[index];

          final String name = app["name"] ?? (lang != 1 ? "< unknown >" : "< nepoznato >");
          final String dev = app["dev"] ?? (lang != 1 ? "< unknown >" : "< nepoznato >");
          final String iconLink = app["icon_link"] ?? "";
          final String downloadLink = app["download_link"] ?? "";
          List<String> screenshots = (app["screenshots"] as List<dynamic>?)
              ?.cast<String>() ?? [];
          final String rating = app["rating"] ?? "N/A";
          final String package = app["package"] ?? "UNSUPPORTED";

          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: iconLink,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: Colors.grey[800]),
                          errorWidget: (_, _, _) => const Icon(Icons.broken_image, size: 64),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              dev,
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            Text(
                              lang != 1 ? "rating: $rating ★ | package: $package" : "ocjena: $rating ★ | id paketa: $package",
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Screenshots horizontal scroll
                  if (screenshots.isNotEmpty && screenshots[0] != "UNSUPPORTED")
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: screenshots.length,
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: screenshots[i],
                                width: 120,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(color: Colors.grey[800]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Download button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: downloadLink.isEmpty
                          ? null
                          : () async {
                              final uri = Uri.parse(downloadLink);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.platformDefault);
                              }
                            },
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: Text(
                        lang != 1 ? "download" : "skini",
                        style: TextStyle(
                          color: Colors.white
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PatcherContent extends StatefulWidget {
  final void Function(int) onPageChange;
  final int lang;

  const PatcherContent({super.key, required this.onPageChange, required this.lang});

  @override
  State<PatcherContent> createState() => _PatcherContentState();
}

class _PatcherContentState extends State<PatcherContent> {
  String? _selectedApkPath;
  String? _selectedApkName;
  bool _isPatching = false;
  String _statusMessage = '';
  String? _patchedApkPath;

  Future<void> _pickApkFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedApkPath = result.files.single.path!;
        _selectedApkName = result.files.single.name;
        _statusMessage = widget.lang != 1
            ? "selected: $_selectedApkName"
            : "izabran: $_selectedApkName";
        _patchedApkPath = null;
      });
    } 
  }

  Future<void> _patchAndDownload() async {
    if (_selectedApkPath == null) return;

    setState(() {
      _isPatching = true;
      _statusMessage = widget.lang != 1 ? "uploading and patching..." : "šaljem i patcham...";
    });

    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
      }

      var uri = Uri.https('necro.absnull.xyz', '/patch');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _selectedApkPath!));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        final patchedPath = '${dir.path}/patched_$_selectedApkName';

        final file = File(patchedPath);
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          _patchedApkPath = patchedPath;
          _statusMessage = widget.lang != 1
              ? "patched .apk saved! ready to install."
              : "patchani .apk fajl spašen! spreman za instalaciju.";
        });
      } else {
        setState(() {
          _statusMessage = widget.lang != 1
              ? "I got an error... ${response.body}"
              : "moja greška... ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = widget.lang != 1
            ? "failed: $e"
            : "neuspješno: $e";
      });
    } finally {
      setState(() => _isPatching = false);
    }
  }

  Future<void> _installPatched() async {
    if (_patchedApkPath == null) return;

    // Check if we can request install permission
    if (await Permission.requestInstallPackages.request().isGranted) {
      final result = await OpenFilex.open(_patchedApkPath!);
      if (result.type != ResultType.done) {
        _showInstallError(result.message);
      }
      return;
    }

    // send to settings if denied
    final AndroidIntent intent = AndroidIntent(
      action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
      data: 'package:${(await PackageInfo.fromPlatform()).packageName}',
    );
    await intent.launch();

    setState(() {
      _statusMessage = widget.lang != 1
          ? "go to settings and allow installs from this app, then try again."
          : "idi u postavke i dozvoli instalacije iz ove aplikacije, pa probaj ponovo.";
    });
  }

void _showInstallError(String msg) {
  setState(() {
    _statusMessage = widget.lang != 1
        ? "Install failed: $msg"
        : "Instalacija neuspješna: $msg";
  });
}

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isPatching) Text(
              widget.lang != 1
                  ? "patch old apps to work on newer Android versions."
                  : "patchaj stare aplikacije da rade na novijim Android verzijama.",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (!_isPatching && _selectedApkPath == null) const SizedBox(height: 40),
            if (!_isPatching && _selectedApkPath == null) ElevatedButton(
              onPressed: _pickApkFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E2E2E),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: Text(
                widget.lang != 1 ? "select .apk file" : "izaberi .apk fajl",
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            if (_selectedApkPath != null) ...[
              ElevatedButton(
                onPressed: _isPatching ? null : _patchAndDownload,
                child: _isPatching
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.lang != 1 ? "patch & download" : "patchaj i preuzmi",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
              const SizedBox(height: 20),
              Text(_statusMessage, textAlign: TextAlign.center),
              if (_patchedApkPath != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _installPatched,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  child: Text(
                    widget.lang != 1 ? "install patched .apk" : "instaliraj patchani .apk",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 30),
            if (!_isPatching && _selectedApkPath == null) Text(widget.lang != 1 ? "don't have an old .apk?" : "nemaš stari .apk?"),
            if (!_isPatching && _selectedApkPath == null) TextButton(
              onPressed: () => widget.onPageChange(0),
              child: Text(
                widget.lang != 1 ? "find an old app to patch" : "nađi staru aplikaciju za patchanje",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsContent extends StatelessWidget {
  final int lang;
  final int maxResults;
  final bool useArchiveResults;
  final void Function(int) onLanguageChange;
  final void Function(int? maxResults, bool? useArchive) onSettingsChange;
  const SettingsContent({
    super.key,
    required this.onLanguageChange,
    required this.lang,
    required this.onSettingsChange,
    required this.maxResults,
    required this.useArchiveResults
  });

  @override
  Widget build(BuildContext context) {
    String currentLanguage = lang == 0 ? "english" : "bosanski";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == 0 ? "necromancer configuration" : "necromancer postavke",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: Text(lang == 0 ? "language" : "jezik"),
            trailing: DropdownButton<String>(
              value: currentLanguage,
              items: ["english", "bosanski"].map((String l) {
                return DropdownMenuItem<String>(value: l, child: Text(l));
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue == "english") {
                  onLanguageChange(0);
                } else if (newValue == "bosanski") {
                  onLanguageChange(1);
                }
              },
            ),
          ),
          ListTile(
            title: Text(lang != 1 ? "maximum number of search results:" : "maksimalni broj rezultata:"),
            subtitle: Slider(
              value: maxResults.toDouble(),
              onChanged: (double newValue) {
                onSettingsChange(newValue.round(), null);
              },
              max: 100,
              divisions: 99,
              min: 1
            ),
            trailing: Text("${maxResults.round()}"),
          ),
          SwitchListTile(
            title: Text(lang != 1 ? "use archive.org results" : "koristi rezultate sa archive.org"),
            value: useArchiveResults,
            onChanged: (bool? newValue) {
              onSettingsChange(null, newValue);
            },
          )
          // more settings to come... probably?
        ],
      ),
    );
  }
}

class AboutContent extends StatelessWidget {
  final int lang;
  final void Function(int) onPageChange;
  const AboutContent({super.key, required this.lang, required this.onPageChange});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsGeometry.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang != 1 ? "about necromancer" : "o necromanceru",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold
            ),
          ),
          Text(lang != 1 ? "\"everything on the internet stays on the internet\"" : "\"sve na internetu na internetu i ostaje\""),
          SizedBox(height: 20),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(horizontalInside: BorderSide(color: Colors.white, width: 0), bottom: BorderSide(color: Colors.white, width: 0.2)),
            children: [
              TableRow(
                children: [
                  Text(lang != 1 ? "developer" : "autor"),
                  Text("Tarik Dedić")
                ]
              ),
              TableRow(
                children: [
                  Text(lang != 1 ? "built in" : "napravljeno u"),
                  Text("Flutter")
                ]
              ),
              TableRow(
                children: [
                  Text(lang != 1 ? "version" : "verzija"),
                  Text(appver)
                ]
              ),
              TableRow(
                children: [
                  Text(lang != 1 ? "providers" : "tražilice"),
                  Text("- Uptodown,\n- OceanOfAPK,\n- Aptoide,\n- ApkPure,\n- Archive.org\n- Web ${(lang != 1 ? "search (coming soon" : "pretraga (uskoro")})")
                ]
              ),
              TableRow(
                children: [
                  Text(lang != 1 ? "uses wifi" : "koristi internet"),
                  Text(lang != 1 ? "yes" : "da")
                ]
              ),
              TableRow(
                children: [
                  Text(lang != 1 ? "open source repo" : "izvorni kod"),
                  // TODO: ADD GITHUB LINK
                  Text("pretend a github link is here")
                ]
              ),
              TableRow(
                children: [
                  ListTile(
                    title: Text(lang != 1 ? "licences" : "licence"),
                    onTap: () => onPageChange(4),
                  ),
                  Center(
                    child: Text(lang != 1 ? "tap to view all the licences of this app." : "dirni da vidiš sve licence aplikacije.")
                  )
                ]
              ),
              TableRow(
                children: [
                  Text(lang != 1 ? "privacy policy" : "privatnost podataka"),
                  Text(lang != 1 ? "the app doesn't collect or store any user information except for the in-app settings. " + 
                  "all requests to third-party services are anonymous. the only services used in the app are needed for said app to function properly. " +
                  "if unsure about the actual function of the app behind these words, refer to the source code."
                  :
                  "aplikacija ne prikuplja ili čuva ikakve podatke o korisniku osim postavki unutar aplikacije. " +
                  "svi 'zahtjevi' poslani vanjskim uslugama su anonimni. jedine usluge koje se koriste u aplikaciji su potrebne da aplikacija funkcioniše. " +
                  "u slučaju nesigurnosti o stvarnim funkcijama aplikacije iza ovih riječi, pogledaj izvorni kod."
                  )
                ]
              ),
              // I'll probably add more rows here later...
            ]
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Image.asset("assets/inapp_icons/flutter.png", width: 50, height: 50),
              Image.asset("assets/inapp_icons/apkpure.png", width: 50, height: 50),
              Image.asset("assets/inapp_icons/aptoide.png", width: 50, height: 50)
            ],
          )
        ]
      )
    );
  }
}

class _MyHomePageState extends State<HomePage> {
  int currentPage = 0; // 0 = home, 1 = patcher, 2 = settings, 3 = about, 4 = licences
  late String greet;

  // settings
  int lang = 0; // 0 = eng, 1 = bos
  int maxNumResults = 50;
  bool showArchiveResults = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lang = prefs.getInt('lang') ?? 0;
      maxNumResults = prefs.getInt('maxNumResults') ?? 50;
      showArchiveResults = prefs.getBool('showArchiveResults') ?? false;
      greet = _selectRandomGreet(lang);
    });
  }

  Widget _getCurrentHomePage()
  {
    switch (currentPage)
    {
      case 0:
        return HomeContent(
          lang: lang,
          greet: greet,
          settings_maxNumResults: maxNumResults,
          settings_showArchiveResults: showArchiveResults
        );
      case 1:
        return PatcherContent(onPageChange: changePage, lang: lang);
      case 2:
        return SettingsContent(
          lang: lang,
          onLanguageChange: changeLanguage,
          onSettingsChange: changeSettings,
          maxResults: maxNumResults,
          useArchiveResults: showArchiveResults
        );
      case 3:
        return AboutContent(lang: lang, onPageChange: changePage);
      case 4:
      return LicensePage(applicationName: "necromancer", applicationVersion: appver);
      case _:
        return HomeContent(
          greet: greet,
          lang: lang,
          settings_maxNumResults: maxNumResults,
          settings_showArchiveResults: showArchiveResults
        );
    }
  }

  void changePage(int page) {
    setState(() => currentPage = page);
  }

  void changeLanguage(int newLang) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('lang', newLang);
    setState(() {
      lang = newLang;
      greet = _selectRandomGreet(newLang);
    });
  }

  void changeSettings(int? newMaxsearchResults, bool? newShowArchiveResults) async {
    final prefs = await SharedPreferences.getInstance();
    if (newMaxsearchResults != null) {
      prefs.setInt('maxNumResults', newMaxsearchResults);
      setState(() => maxNumResults = newMaxsearchResults);
    }
    if (newShowArchiveResults != null) {
      prefs.setBool('showArchiveResults', newShowArchiveResults);
      setState(() => showArchiveResults = newShowArchiveResults);
    }
  }

  Widget _buildTitle(String english, String bosnian) {
    String text = lang != 1 ? english : bosnian;
    bool isSelected = false;

    if ((english == "home" || bosnian == "početna") && currentPage == 0) isSelected = true;
    if (english == "patcher" && currentPage == 1) isSelected = true;
    if ((english == "configuration" || bosnian == "postavke") && currentPage == 2) isSelected = true;
    if ((english == "about" || bosnian == "o aplikaciji") && currentPage == 3) isSelected = true;

    return Text(
      isSelected ? "< $text >" : text,
      style: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
              ),
              child: const Text(
                "necromancer",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: _buildTitle("home", "početna"),
              onTap: () {
                setState(() {
                  currentPage = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.asset("assets/inapp_icons/patcher.png", width: 20, height: 20),
              title: _buildTitle("patcher", "patcher"),
              onTap: () {
                setState(() {
                  currentPage = 1;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: _buildTitle("configuration", "postavke"),
              onTap: () {
                setState(() {
                  currentPage = 2;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_rounded),
              title: _buildTitle("about", "o aplikaciji"),
              onTap: () {
                setState(() {
                  currentPage = 3;
                });
                Navigator.pop(context);
              },
            ),
            // more features later...?
          ],
        ),
      ),
      body: _getCurrentHomePage()
    );
  }
}
