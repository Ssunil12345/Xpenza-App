# Xpenza - Modern Expense Tracker

A beautiful and feature-rich expense tracking app built with Flutter, supporting both Android and iOS platforms.

## 🎯 Features

### ✨ New Features Added
1. **Monthly View** - View expenses for any selected month with easy navigation
2. **Yearly View** - Track annual spending patterns and trends
3. **Custom Categories** - Add unlimited custom expense categories beyond the default ones
4. **Interactive Date Selectors** - Easily navigate between months and years
5. **Enhanced UI** - Modern, attractive design with smooth animations
6. **Dark Mode** - Beautiful dark theme support

### 📊 Core Features
- Add, edit, and delete expenses
- Categorize expenses (Food, Transport, Shopping, Bills + Custom)
- Search and filter transactions
- Visual charts showing spending by category
- Monthly budget tracking with progress indicator
- PDF export of expense reports
- Swipe to delete expenses
- Real-time data synchronization

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0 or higher)
- Dart SDK
- For iOS: Xcode 14+ and macOS
- For Android: Android Studio

### Installation

1. **Clone or create the project**
```bash
flutter create expense_tracker
cd expense_tracker
```

2. **Add dependencies to `pubspec.yaml`**
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management & Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # UI Components
  fl_chart: ^0.65.0
  intl: ^0.18.1
  
  # PDF Generation
  pdf: ^3.10.7
  printing: ^5.11.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  hive_generator: ^2.0.1
  build_runner: ^2.4.6
```

3. **Install dependencies**
```bash
flutter pub get
```

4. **Create project structure**
```
lib/
├── main.dart
├── models/
│   ├── expense_model.dart
│   └── expense_model.g.dart (generated)
└── screens/
    ├── home_screen.dart
    └── add_expense_screen.dart
```

5. **Replace the files with the provided code**
- Copy `home_screen.dart` to `lib/screens/home_screen.dart`
- Copy `add_expense_screen.dart` to `lib/screens/add_expense_screen.dart`
- Keep your existing `expense_model.dart` and `main.dart`

6. **Run build_runner to generate Hive adapters**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📱 iOS Setup

### 1. Configure iOS Project

Open `ios/Runner/Info.plist` and add these permissions:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to save PDF reports to your photo library</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need access to save PDF reports</string>
```

### 2. Set Minimum iOS Version

Open `ios/Podfile` and ensure minimum iOS version is set:

```ruby
platform :ios, '12.0'
```

### 3. Install iOS Pods

```bash
cd ios
pod install
cd ..
```

### 4. Open in Xcode (Optional but Recommended)

```bash
open ios/Runner.xcworkspace
```

In Xcode:
- Select your development team in Signing & Capabilities
- Ensure Bundle Identifier is unique (e.g., com.yourname.xpenza)
- Check that deployment target is iOS 12.0+

### 5. Run on iOS

```bash
# For iOS Simulator
flutter run

# For physical iOS device
flutter run -d <device-id>
```

## 🎨 App Usage Guide

### Adding Expenses
1. Tap the **"+ Add Expense"** floating button
2. Fill in:
   - Title (e.g., "Lunch at Restaurant")
   - Amount (e.g., 500)
   - Category (Food, Transport, Shopping, Bills, or your custom categories)
   - Date (tap to select)
3. Tap **"Save Expense"**

### Viewing by Time Period
- **All Tab**: View all expenses
- **Today Tab**: See today's expenses only
- **Monthly Tab**: Use arrows or tap date to select a specific month
- **Yearly Tab**: Use arrows or tap year to select a specific year

### Creating Custom Categories
1. Tap the **Settings** icon (⚙️)
2. Enter category name in "Custom Categories" field
3. Tap the **"+"** button
4. Your new category is now available in the dropdown!

### Searching & Filtering
- Use the search bar to find specific transactions
- Filter by category using the chips below the search bar
- Combine search with date filters for precise results

### Managing Budget
1. Tap **Settings** icon
2. Enter your monthly budget
3. Tap **"Save"**
4. Watch your progress on the main screen

### Exporting Reports
1. Tap the **PDF** icon (📄)
2. Choose to save or share the PDF
3. Report includes all filtered expenses with totals

## 🎯 Features Breakdown

### 1. Monthly Expenses
- Switch to "Monthly" tab
- Navigate months using arrow buttons
- Tap on date selector to jump to any month
- View total spending for selected month

### 2. Yearly Expenses
- Switch to "Yearly" tab
- Navigate years using arrow buttons
- Tap on year to open year picker
- See annual spending patterns

### 3. Custom Categories
Default categories: Food, Transport, Shopping, Bills

Add custom categories for:
- Entertainment
- Healthcare
- Education
- Utilities
- Subscriptions
- Gifts
- Travel
- And more!

### 4. Visual Analytics
- **Pie Chart**: Shows spending distribution by category
- **Budget Progress Bar**: Visual indicator of budget usage
- **Category Colors**: Each category has a unique color for easy identification

## 🛠️ Troubleshooting

### iOS Build Issues

**Issue**: Pod install fails
```bash
cd ios
pod deintegrate
pod install
```

**Issue**: Signing error
- Open Xcode
- Select Runner target
- Go to Signing & Capabilities
- Select your development team

**Issue**: Architecture warnings
- Update Podfile with:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

### Android Build Issues

**Issue**: Minimum SDK version
In `android/app/build.gradle`:
```gradle
minSdkVersion 21
```

## 📊 Data Storage

- Uses **Hive** (NoSQL local database)
- Data persists across app restarts
- Two boxes:
  - `expenses`: Stores all expense records
  - `settings`: Stores user preferences (budget, dark mode, custom categories)

## 🎨 Customization

### Change App Colors
Edit the theme in `main.dart`:
```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: Colors.indigo, // Change this color
  brightness: Brightness.light,
)
```

### Change Currency Symbol
Replace `₹` with your currency symbol in:
- `home_screen.dart`
- `add_expense_screen.dart`

### Add More Default Categories
In `home_screen.dart`, modify:
```dart
List<String> _getCategories() {
  return [
    "All",
    "Food",
    "Transport",
    "Shopping",
    "Bills",
    "Entertainment", // Add new categories here
    ...
  ];
}
```

## 📝 License

This project is open source and available for personal and commercial use.

## 🤝 Contributing

Feel free to fork, modify, and enhance the app! Suggestions for improvements:
- Cloud sync
- Recurring expenses
- Budget alerts
- Multiple currencies
- Data backup/restore
- Expense sharing

## 📧 Support

For issues or questions, please create an issue in the repository.

---

**Enjoy tracking your expenses with Xpenza! 💰📊**
