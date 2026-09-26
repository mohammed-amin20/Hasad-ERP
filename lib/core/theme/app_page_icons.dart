import 'package:font_awesome_flutter/font_awesome_flutter.dart';
abstract final class AppPageIcons {
  static const Map<String, FaIconData> _byTitle = {
    'لوحة التحكم': FontAwesomeIcons.gaugeHigh,
    'المبيعات': FontAwesomeIcons.cashRegister,
    'المشتريات': FontAwesomeIcons.truck,
    'العملاء': FontAwesomeIcons.userGroup,
    'الموردون': FontAwesomeIcons.warehouse,
    'المنتجات': FontAwesomeIcons.boxesStacked,
    'المخزون': FontAwesomeIcons.clipboardList,
    'المصاريف': FontAwesomeIcons.receipt,
    'الموظفون': FontAwesomeIcons.userTie,
    'الرواتب': FontAwesomeIcons.userGear,
    'الذمم والاستحقاقات': FontAwesomeIcons.handHoldingDollar,
    'دليل الحسابات': FontAwesomeIcons.sitemap,
    'قيد اليومية': FontAwesomeIcons.book,
    'الأستاذ العام': FontAwesomeIcons.bookOpen,
    'ميزان المراجعة': FontAwesomeIcons.scaleBalanced,
    'القوائم المالية': FontAwesomeIcons.chartBar,
    'الإعدادات': FontAwesomeIcons.gear,
    'تسجيل الدخول': FontAwesomeIcons.rightToBracket,
  };

  static FaIconData? of(String title) => _byTitle[title];
}
