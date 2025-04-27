import 'package:flutter/material.dart';
import '../models/onboarding_page_models.dart';
import '../widgets/onboarding_button.dart';
import '../widgets/onboarding_page_indicator.dart';
import '../widgets/onboarding_skip_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

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
      title: "Get New Contracts Faster",
      description: "Browse job offers, submit quotes, and grow your business with less hassle.",
      imageAsset: "assets/images/contractor.png",
    ),
    OnboardingPageModel(
      title: "Find Trusted Professionals",
      description: "Post your building project and get offers from verified contractors in just a few clicks.",
      imageAsset: "assets/images/client.png",
    ),
    OnboardingPageModel(
      title: "Let's Get Started",
      description: "Let's get into it together!",
      imageAsset: "assets/images/get_started.png",
    ),
  ];

  void _nextPage() {
    if (_currentIndex < onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // TODO: Go to Register/Login page
      Navigator.pushNamed(context, '/login'); // or whatever route you setup
    }
  }

  void _skip() {
    _pageController.animateToPage(
      onboardingPages.length - 1,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFD),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingPages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = onboardingPages[index];
                  return Padding(
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
                  );
                },
              ),
            ),

            OnboardingPageIndicator(
              currentIndex: _currentIndex,
              pageCount: onboardingPages.length,
            ),

            const SizedBox(height: 20),

          Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (_currentIndex == 1) ...[
                // Two buttons for the second onboarding screen
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Action for the first button on the second screen
                      print("Button 1 on screen 2 pressed");
                      _nextPage(); // Example action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Client', style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Action for the second button on the second screen
                      print("Button 2 on screen 2 pressed");
                      _nextPage(); // Example action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Contractor', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ]else if (_currentIndex == 4) ...[
                // Two buttons for the second onboarding screen
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Action for the first button on the second screen
                      print("Button 1 on screen 2 pressed");
                      _nextPage(); // Example action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Login', style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Action for the second button on the second screen
                      print("Button 2 on screen 5 pressed");
                      _nextPage(); // Example action
                    },
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
                // "Skip" and "Next" buttons for all screens except the second and the last
                
                OnboardingButton(
                  text: 'Next',
                  onPressed: _nextPage,
                ),
                OnboardingSkipButton(onPressed: _skip),
              ] else ...[
                // "Get Started" button on the last screen
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _nextPage, // Navigates to /login
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
