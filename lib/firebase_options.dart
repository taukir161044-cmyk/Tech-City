// প্লেসহোল্ডার। GitHub Actions বিল্ডের সময় এটা আপনার আসল Firebase কনফিগ দিয়ে বদলে যায়।
// লোকাল মেশিনে চালাতে চাইলে এখানে নিজের google-services.json এর মান বসান।
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
  );
}
