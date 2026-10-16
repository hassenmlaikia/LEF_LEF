enum AppRole { client, driver, deliveryProvider, partner, owner, manager, employee, moderator }

enum ServiceKind { taxiMoto, carExpress, deliveryMoto, deliveryVan, deliveryTruck, sos, ambulance, randonnee }

enum RideStatus { draft, searching, offered, countered, accepted, arriving, arrived, active, completed, cancelled }

enum Capability { manageUsers, manageRoles, manageServices, manageRides, manageSubscriptions, manageNotifications, moderateContent, viewDashboard }

const roleCapabilities = <AppRole, Set<Capability>>{
  AppRole.owner: {Capability.manageUsers, Capability.manageRoles, Capability.manageServices, Capability.manageRides, Capability.manageSubscriptions, Capability.manageNotifications, Capability.moderateContent, Capability.viewDashboard},
  AppRole.manager: {Capability.manageRides},
  AppRole.moderator: {Capability.moderateContent},
  AppRole.partner: {Capability.manageRides},
  AppRole.driver: {Capability.manageRides},
  AppRole.deliveryProvider: {Capability.manageRides},
  AppRole.employee: {},
  AppRole.client: {},
};

Set<Capability> defaultCapabilitiesForRole(AppRole role) => {...(roleCapabilities[role] ?? const <Capability>{})};

List<String> capabilityNames(Set<Capability> capabilities) => capabilities.map((c) => c.name).toList()..sort();

String capabilityLabel(Capability c) => switch (c) {
  Capability.manageUsers => 'إدارة المستخدمين',
  Capability.manageRoles => 'إدارة الأدوار',
  Capability.manageServices => 'إدارة الخدمات',
  Capability.manageRides => 'إدارة المشاوير',
  Capability.manageSubscriptions => 'إدارة الاشتراكات',
  Capability.manageNotifications => 'إدارة الإشعارات',
  Capability.moderateContent => 'مراقبة المحتوى',
  Capability.viewDashboard => 'مشاهدة لوحة المتابعة',
};

String rideStageLabel(String status) => switch (status) {
  'searching' => 'نلوجو على السائق مناسب',
  'offered' => 'جاك عرض من السائق',
  'countered' => 'مستنيين في الردّ على العرض المضاد',
  'accepted' => 'تعيّن السائق',
  'arriving' => 'السائق في الثنية',
  'arrived' => 'السائق وصل للبلاصة',
  'active' => 'المشوار قاعد يصير',
  'completed' => 'الخدمة كملت',
  'cancelled' => 'الخدمة تلغات',
  _ => 'جاهز',
};

class ServiceOption {
  final ServiceKind kind;
  final String title;
  final String subtitle;
  final double base;
  final double dayKm;
  final double nightKm;
  final bool negotiable;
  const ServiceOption(this.kind, this.title, this.subtitle, this.base, this.dayKm, this.nightKm, {this.negotiable=false});
}

const serviceOptions = <ServiceOption>[
  ServiceOption(ServiceKind.taxiMoto, 'تاكسي موتو', 'تنقّل داخل المدينة', 2.00, 1.00, 1.50),
  ServiceOption(ServiceKind.carExpress, 'كار / إكسبراس', 'تنقّل بالسيارة', 4.00, 1.00, 1.50),
  ServiceOption(ServiceKind.deliveryMoto, 'ديليفري موتو', 'توصيل الطلبات والطرود', 2.00, 1.00, 1.50),
  ServiceOption(ServiceKind.deliveryVan, 'ديليفري فان', 'توصيل الحمولة بالفان', 4.00, 1.00, 1.50),
  ServiceOption(ServiceKind.deliveryTruck, 'إيسوزو / كاميون', 'نقل الحمولة الكبيرة', 0.00, 0.00, 0.00, negotiable:true),
  ServiceOption(ServiceKind.sos, 'SOS (إيسوسو)', 'خدمة SOS مستقلة', 0.00, 0.00, 0.00, negotiable:true),
  ServiceOption(ServiceKind.ambulance, 'إسعاف', 'نقل صحي استعجالي', 0.00, 0.00, 0.00, negotiable:true),
  ServiceOption(ServiceKind.randonnee, 'روندوناي', 'جولات وأنشطة', 0.00, 0.00, 0.00, negotiable:true),
];

String roleLabel(AppRole role) => switch (role) {
  AppRole.client => 'الحريف',
  AppRole.driver => 'سائق',
  AppRole.deliveryProvider => 'ليفرور',
  AppRole.partner => 'شريك / شركة',
  AppRole.owner => 'المالك',
  AppRole.manager => 'مسؤول',
  AppRole.employee => 'موظف',
  AppRole.moderator => 'مراقب محتوى',
};

String serviceLabel(ServiceKind kind) => serviceOptions.firstWhere((e) => e.kind == kind).title;
