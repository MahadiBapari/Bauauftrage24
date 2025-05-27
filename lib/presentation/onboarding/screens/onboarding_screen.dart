import 'package:flutter/material.dart';
import '../models/onboarding_page_models.dart';
import '../widgets/onboarding_button.dart';
import '../widgets/onboarding_page_indicator.dart';
import '../widgets/onboarding_skip_button.dart';
// Import LoginPage
// Import Client Register Screen
// Import Contractor Register Screen

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentIndex = 0;
  String? _userType; // To store if the user chose 'client' or 'contractor'

  final List<OnboardingPageModel> onboardingPages = [
    OnboardingPageModel(
      title: "Welcome to Bauaufträge24!",
      description: "Find and manage construction projects easily — anytime, anywhere.",
      imageAsset: "assets/images/welcome.png",
    ),
    OnboardingPageModel(
      title: "Find Projects & Professionals",
      description: "From finding the perfect contractor to discovering new job opportunities, we've got you covered.",
      imageAsset: "assets/images/client_contractor.png",
    ),
    OnboardingPageModel(
      title: "Find Trusted Professionals",
      description: "Post your building project and get offers from verified contractors in just a few clicks.",
      imageAsset: "assets/images/client.png",
    ),
    OnboardingPageModel(
      title: "Get New Contracts Faster",
      description: "Browse job offers, submit quotes, and grow your business with less hassle.",
      imageAsset: "assets/images/contractor.png",
    ),
    OnboardingPageModel(
      title: "Let's Get Started",
      description: "Let's get into it together!",
      imageAsset: "assets/images/get_started.png",
    ),
  ];

 void _nextPage() {
  setState(() {
    if (_currentIndex == 0) {
      // Welcome -> ChoosingPage
      _currentIndex = 1;
    } 
    else if (_currentIndex == 1) {
      // ChoosingPage -> Route based on user type
      if (_userType == 'client') {
        _currentIndex = 2; // Go to ClientPage
      } else if (_userType == 'contractor') {
        _currentIndex = 3; // Go to ContractorPage
      }
    } 
    else if ((_currentIndex == 2 && _userType == 'client') ||
             (_currentIndex == 3 && _userType == 'contractor')) {
      // From either ClientPage or ContractorPage -> GetStarted
      _currentIndex = 4;
    } 
    else if (_currentIndex == 4) {
      // From GetStarted -> Navigate to login or register
      Navigator.pushNamed(context, '/login'); // route logic
    }
  });
}

  void _previousPage() {
    if (_currentIndex > 0) {
      setState(() {
        if (_currentIndex == 4) {
          // Go back to the appropriate info page
          _currentIndex = _userType == 'client' ? 3 : 2;
        } else if (_currentIndex == 2 || _currentIndex == 3) {
          _currentIndex = 1; // Go back to role selection
        } else {
          _currentIndex--;
        }
      });
    }
  }

  void _skip() {
    setState(() {
      _currentIndex = onboardingPages.length - 1;
    });
  }

  void _handleRoleSelection(String role) {
    setState(() {
      _userType = role;
    });
    _nextPage(); // Move to the next relevant page
  }

  //indicator login
  int getVisualIndex(int index) {
    if (index == 0) return 0; // Welcome
    if (index == 1) return 1; // ChoosingPage
    if (index == 2 || index == 3) return 2; // ClientPage OR ContractorPage
    if (index == 4) return 3; // GetStarted
    return 0;
  }


  //register navigation
  void _navigateToRegister() {
    if (_userType == 'client') {
      Navigator.pushNamed(context, '/register_client');
    } else if (_userType == 'contractor') {
      Navigator.pushNamed(context, '/register_contractor');
    } else {
      Navigator.pushNamed(context, '/register_client');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: _previousPage,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: List.generate(onboardingPages.length, (index) {
                  final page = onboardingPages[index];
                  return AnimatedOpacity(
                    opacity: _currentIndex == index ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Visibility(
                      visible: _currentIndex == index,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Image.asset(page.imageAsset),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              page.title,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page.description,
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            OnboardingPageIndicator(
              currentIndex: getVisualIndex(_currentIndex),  // use visual index here
              pageCount: 4,
            ),


            //role selection
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (_currentIndex == 1) ...[
                    SizedBox(
                      width: 150,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _handleRoleSelection('client'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Client', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 150,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _handleRoleSelection('contractor'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Contractor', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ] else if (_currentIndex == 4) ...[
                    SizedBox(
                      width: 150,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Login', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 150,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _navigateToRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Register', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ] else if (_currentIndex != onboardingPages.length - 1) ...[
                    OnboardingButton(
                      text: 'Next',
                      onPressed: _nextPage,
                    ),
                    OnboardingSkipButton(onPressed: _skip),
                  ] else ...[
                    SizedBox(
                      width: 200,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.red.shade800,
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}