import 'package:flutter/material.dart';

class SupportAndHelpPageScreen extends StatelessWidget {
  const SupportAndHelpPageScreen({super.key});

  
  Widget _buildSectionHeader(String title) {
    return Column(
      children: [
        const SizedBox(height: 24), 
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[400])), 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                title.toUpperCase(), 
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[400])), 
          ],
        ),
        const SizedBox(height: 16), 
      ],
    );
  }

  // Helper widget to build a simple horizontal divider between items
  Widget _buildSimpleDivider() {
    return Divider(
      color: Colors.grey[200],
      height: 1,
      thickness: 1,
      indent: 16, 
      endIndent: 16, 
    );
  }

  @override
  Widget build(BuildContext context) {
    final faqList = [
      {
        'question': 'Welche Art von Aufträgen kann ich auf Bauaufträge24.ch einstellen?',
        'answer': '''Auf Bauaufträge24.ch können Sie eine Vielzahl von Bau- und Handwerksaufträgen einstellen. Egal, ob es sich um kleine Reparaturen, Renovierungen, Neubauten oder spezifische Handwerksleistungen handelt – unsere Plattform verbindet Sie mit qualifizierten, zertifizierten Handwerkern für jedes Projekt.
Von klassischen Handwerksleistungen wie Malerarbeiten, Elektrik, Sanitärinstallationen bis hin zu komplexeren Bauprojekten wie Fassadenrenovierungen, Innenausbau oder Gartenarbeiten – auf Bauaufträge24.ch finden Sie den richtigen Handwerker für Ihre Bedürfnisse.
Stellen Sie einfach Ihr Projekt ein, und lassen Sie sich von unseren professionellen Handwerkern Angebote unterbreiten!'''
      },
      {
        'question': 'Wie hoch sind die Kosten für die Handwerker auf Bauaufträge24.ch?',
        'answer': '''Für Handwerker gibt es eine einmalige Jahresgebühr von 1290 CHF. Diese Gebühr ermöglicht es Ihnen, das gesamte Jahr über auf Bauaufträge zuzugreifen und von unseren Kunden kontaktiert zu werden – ohne versteckte Zusatzkosten oder Provisionen.
Mit dieser Gebühr erhalten Sie einen vollen Zugang zu einer Vielzahl von Aufträgen und profitieren von einer exklusiven Sichtbarkeit auf der Plattform. So können Sie sich auf das konzentrieren, was wirklich zählt: Ihre Arbeit – ohne sich um zusätzliche Gebühren kümmern zu müssen.'''
      },
      {
        'question': 'Wie kann ich sicherstellen, dass der Handwerker zuverlässig und qualifiziert ist?',
        'answer': '''Ja, alle Handwerker auf Bauaufträge24.ch sind zertifiziert und verifiziert. Wir legen großen Wert darauf, nur qualifizierte und vertrauenswürdige Handwerker auf unserer Plattform zuzulassen. Jeder Handwerker wird sorgfältig überprüft, einschließlich einer Überprüfung seiner Qualifikationen, seiner Registrierung im Handelsregister und seiner Berufserfahrung.
Um sicherzustellen, dass Sie auf Experten zählen können, führen wir auch regelmäßige Telefonate und persönliche Besuche durch. So garantieren wir, dass unsere Handwerker zuverlässig sind und den höchsten Standards entsprechen.'''
      },
      {
        'question': 'Kann ich den Handwerker direkt kontaktieren, um Details zu besprechen?',
        'answer': '''Ja, Sie können die Handwerker direkt kontaktieren, um alle Details Ihres Projekts zu besprechen. Sobald Sie einen Handwerker ausgewählt haben, haben Sie die Möglichkeit, mit ihm in Kontakt zu treten und die Einzelheiten zu klären.
Darüber hinaus haben auch die Handwerker die Möglichkeit, auf Ihre Anfrage zu reagieren und Ihnen ein Angebot zu unterbreiten. So können Sie sicherstellen, dass alle Fragen geklärt sind, bevor der Auftrag beginnt, und den Handwerker auswählen, der am besten zu Ihrem Projekt passt.'''
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Support & Help'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0), 
        children: [


          // --- Our Office Hours Section ---
          _buildSectionHeader('Our Office Hours'),
          Card(
            margin: EdgeInsets.zero, 
            color: Colors.white,
            elevation: 0, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), 
            child: const ListTile(
              leading: Icon(Icons.access_time, color: Colors.brown),
              title: Text(
                'Mon - Fri: 9:00 AM - 5:00 PM',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.normal),
              ),
              subtitle: Text(
                'Closed on weekends and public holidays',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          _buildSimpleDivider(), 

          // --- Get in Touch Section ---
          _buildSectionHeader('Get in Touch'),
          Card(
            margin: EdgeInsets.zero, 
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            child: const ListTile(
              leading: Icon(Icons.email_outlined, color: Colors.brown),
              title: Text(
                'support@yourcompany.com',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.normal),
              ),
              subtitle: Text(
                'Email us your queries',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          _buildSimpleDivider(), 
          Card(
            margin: EdgeInsets.zero, 
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            child: const ListTile(
              leading: Icon(Icons.phone_outlined, color: Colors.brown),
              title: Text(
                '+41 12 345 6789',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.normal),
              ),
              subtitle: Text(
                'Call during office hours',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          _buildSimpleDivider(), 
          const SizedBox(height: 24),
          
          // --- Frequently Asked Questions Section ---
          _buildSectionHeader('FAQ'),
          ...faqList.map((faq) => Column(
            children: [
              ExpansionTile(
                title: Text(
                  faq['question']!,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        faq['answer']!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ),
                ],
              ),
              _buildSimpleDivider(), 
            ],
          )), 
        ],
      ),
    );
  }
}