/// Where the vaccine schedules in `egypt_vaccines.dart` come from, all
/// opened on 2026-11-04. Details and disagreements:
/// docs/research/egypt-vaccine-schedule.md.
typedef VaccineSource = ({
  String title,
  String publisher,
  String date,
  String url,
});

const egyptVaccineSources = <VaccineSource>[
  (
    title: 'Egypt: WHO and UNICEF estimates of immunization coverage, 2025 revision',
    publisher: 'WHO / UNICEF',
    date: '2026-07-07',
    url: 'https://data.unicef.org/wp-content/uploads/cp-local/wuenic-2026/wuenic_egy.pdf',
  ),
  (
    title: '«الصحة» تكشف خريطة تطعيمات الأطفال من الولادة حتى 18 شهرًا',
    publisher: 'Al-Watan (MoHP schedule)',
    date: '2026-06-17',
    url: 'https://www.elwatannews.com/news/details/8303616',
  ),
  (
    title: 'تطعيمات الأطفال في عمر عام',
    publisher: 'Al-Watan (MoHP schedule)',
    date: '2026-04-30',
    url: 'https://www.elwatannews.com/news/details/8276074',
  ),
  (
    title: 'الصحة تعلن الإجراءات الجديدة للتطعيم ضد شلل الأطفال',
    publisher: 'Al-Bawaba (MoHP, IPV 3 doses)',
    date: '2021-07-09',
    url: 'https://www.albawabhnews.com/4390863',
  ),
  (
    title: '«فاكسيرا» تعلن مواعيد وجرعات التطعيم السداسى',
    publisher: 'Youm7 (VACSERA hexavalent)',
    date: '2026-06-21',
    url: 'https://www.youm7.com/story/2026/6/21/«فاكسيرا»-تعلن-مواعيد-وجرعات-التطعيم-السداسى-لحماية-الأطفال-من-6/7453204',
  ),
  (
    title: 'من يوم حتى 18 شهرًا.. التطعيمات الإجبارية والاختيارية',
    publisher: 'Al-Ahram Gate (optional vaccines)',
    date: '2022-05-23',
    url: 'https://gate.ahram.org.eg/News/3524751.aspx',
  ),
  (
    title: 'مصر تبدأ تصنيع لقاح المكورات الرئوية محليًا',
    publisher: 'Banker News (PCV not yet public)',
    date: '2026-10-26',
    url: 'https://banker.news/157651',
  ),
  (
    title: 'Luxury jabs: The cost of immunity in a two-tiered childhood',
    publisher: 'Al Manassa (PCV, rotavirus private)',
    date: '2026-06-10',
    url: 'https://almanassa.com/en/stories/32274',
  ),
];
