import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'screens/camera_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {

  WidgetsFlutterBinding.ensureInitialized();

    await dotenv.load(fileName: ".env");
    //print(".env file loaded successfully!")
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1280, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AImazing KYC',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: CameraScreen(), 
        );
      },
    );
  }
}