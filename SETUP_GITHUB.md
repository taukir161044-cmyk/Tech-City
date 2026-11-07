# GitHub দিয়ে APK বানানো (কম্পিউটার/Flutter ইনস্টল ছাড়াই)

## ১. Firebase (একবার)
1. console.firebase.google.com এ প্রজেক্ট বানান।
2. **Authentication → Email/Password** চালু করুন।
3. **Firestore Database** বানান, তারপর **Rules** এ `firestore.rules` এর লেখা পেস্ট করে Publish করুন।
4. প্রজেক্টে **Android অ্যাপ যোগ করুন**, Package name অবশ্যই: `com.techcity.tech_city`
   (SHA-1 লাগবে না, বাকি ধাপ Skip করুন)
5. `google-services.json` ডাউনলোড করুন।

## ২. GitHub রিপো
1. নতুন প্রাইভেট রিপো বানান।
2. এই জিপের সব ফাইল রিপোতে আপলোড করুন (`lib/`, `.github/`, `firestore.rules` ইত্যাদি)।
   ফোল্ডারসহ আপলোড ফোনে কঠিন হলে কম্পিউটার থেকে করুন, অথবা Claude কে রিপোর নাম দিন, সে সরাসরি পুশ করে দেবে।

## ৩. Secret
রিপো → **Settings → Secrets and variables → Actions → New repository secret**
- Name: `GOOGLE_SERVICES_JSON`
- Value: `google-services.json` ফাইল খুলে পুরো লেখা কপি করে পেস্ট করুন।

## ৪. বিল্ড
রিপো → **Actions → Build APK → Run workflow**। ৫–১০ মিনিট লাগে।
শেষ হলে সেই রানের পেজের নিচে **Artifacts → tech-city-apk** ডাউনলোড করুন (জিপের ভেতরে `app-release.apk`), ফোনে ইনস্টল করুন।

এরপর README এর ধাপ ৩ (অ্যাডমিন অ্যাকাউন্ট সবার আগে খোলা) করুন।

## সমস্যা হলে
Actions এর লাল রানে ক্লিক করে ব্যর্থ ধাপের এরর লেখা কপি করে Claude কে পাঠান।
