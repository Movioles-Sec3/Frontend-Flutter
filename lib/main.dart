import 'package:flutter/material.dart';
import 'package:flutter_tapandtoast/pages/order_summary_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF4A90E2);
    const Color secondary = Color(0xFF7B61FF);
    const Color accent = Color(0xFFFF6B6B); // used as error/attention

    final TextTheme lightTextTheme =
        GoogleFonts.interTextTheme(ThemeData.light().textTheme)
            .copyWith(
              titleLarge: GoogleFonts.montserrat(
                textStyle: ThemeData.light().textTheme.titleLarge,
                fontWeight: FontWeight.w600,
              ),
            )
            .apply(
              bodyColor: const Color(0xFF1A1A1A),
              displayColor: const Color(0xFF1A1A1A),
            );

    final TextTheme darkTextTheme =
        GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
            .copyWith(
              titleLarge: GoogleFonts.montserrat(
                textStyle: ThemeData.dark().textTheme.titleLarge,
                fontWeight: FontWeight.w600,
              ),
            )
            .apply(bodyColor: Colors.white, displayColor: Colors.white);

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: accent,
        onError: Colors.white,
        surface: Color(0xFFF5F7FA),
        onSurface: Color(0xFF1A1A1A),
      ),
      textTheme: lightTextTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFF5F7FA),
        foregroundColor: Color(0xFF1A1A1A),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF5F6A7D),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: accent,
        onError: Colors.white,
        surface: Color(0xFF121212),
        onSurface: Colors.white,
      ),
      textTheme: darkTextTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFFB0B3B8),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
    );

    return MaterialApp(
      title: 'TapAndToast',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;

  static const List<String> _titles = <String>[
    'Home',
    'Search',
    'Orders',
    'Profile',
  ];

  final List<CartItem> _cart = const [
    CartItem(
      name: 'Craft IPA Beer',
      quantity: 2,
      unitPrice: 5.00,
      image: 'assets/img/beer.png',
    ),
    CartItem(
      name: 'Assorted Tapas',
      quantity: 1,
      unitPrice: 10.00,
      image: 'assets/img/tapas.png',
    ),
    CartItem(
      name: 'Lemon Soda',
      quantity: 3,
      unitPrice: 1.67,
      image: 'assets/img/soda.png',
    ),
  ];

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    Center(child: Text('Search')),
    Center(child: Text('Orders')),
    Center(child: Text('Profile')),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        actions: _currentIndex == 0
            ? <Widget>[
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderSummaryPage(
                          items: _cart,
                          taxRate: 0.10, // 10% (ajústalo)
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart_outlined),
                  tooltip: 'Cart',
                ),
              ]
            : null,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
