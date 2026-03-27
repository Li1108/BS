// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AddressEditPage]
class AddressEditRoute extends PageRouteInfo<AddressEditRouteArgs> {
  AddressEditRoute({Key? key, int? addressId, List<PageRouteInfo>? children})
    : super(
        AddressEditRoute.name,
        args: AddressEditRouteArgs(key: key, addressId: addressId),
        rawPathParams: {'addressId': addressId},
        initialChildren: children,
      );

  static const String name = 'AddressEditRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<AddressEditRouteArgs>(
        orElse: () =>
            AddressEditRouteArgs(addressId: pathParams.optInt('addressId')),
      );
      return AddressEditPage(key: args.key, addressId: args.addressId);
    },
  );
}

class AddressEditRouteArgs {
  const AddressEditRouteArgs({this.key, this.addressId});

  final Key? key;

  final int? addressId;

  @override
  String toString() {
    return 'AddressEditRouteArgs{key: $key, addressId: $addressId}';
  }
}

/// generated route for
/// [AddressListPage]
class AddressListRoute extends PageRouteInfo<AddressListRouteArgs> {
  AddressListRoute({
    Key? key,
    bool selectMode = false,
    List<PageRouteInfo>? children,
  }) : super(
         AddressListRoute.name,
         args: AddressListRouteArgs(key: key, selectMode: selectMode),
         initialChildren: children,
       );

  static const String name = 'AddressListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AddressListRouteArgs>(
        orElse: () => const AddressListRouteArgs(),
      );
      return AddressListPage(key: args.key, selectMode: args.selectMode);
    },
  );
}

class AddressListRouteArgs {
  const AddressListRouteArgs({this.key, this.selectMode = false});

  final Key? key;

  final bool selectMode;

  @override
  String toString() {
    return 'AddressListRouteArgs{key: $key, selectMode: $selectMode}';
  }
}

/// generated route for
/// [EvaluationScreenPage]
class EvaluationScreenRoute extends PageRouteInfo<EvaluationScreenRouteArgs> {
  EvaluationScreenRoute({
    Key? key,
    required int orderId,
    List<PageRouteInfo>? children,
  }) : super(
         EvaluationScreenRoute.name,
         args: EvaluationScreenRouteArgs(key: key, orderId: orderId),
         rawPathParams: {'orderId': orderId},
         initialChildren: children,
       );

  static const String name = 'EvaluationScreenRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<EvaluationScreenRouteArgs>(
        orElse: () =>
            EvaluationScreenRouteArgs(orderId: pathParams.getInt('orderId')),
      );
      return EvaluationScreenPage(key: args.key, orderId: args.orderId);
    },
  );
}

class EvaluationScreenRouteArgs {
  const EvaluationScreenRouteArgs({this.key, required this.orderId});

  final Key? key;

  final int orderId;

  @override
  String toString() {
    return 'EvaluationScreenRouteArgs{key: $key, orderId: $orderId}';
  }
}

/// generated route for
/// [LoginPage]
class LoginRoute extends PageRouteInfo<void> {
  const LoginRoute({List<PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LoginPage();
    },
  );
}

/// generated route for
/// [MessageCenterPage]
class MessageCenterRoute extends PageRouteInfo<MessageCenterRouteArgs> {
  MessageCenterRoute({
    Key? key,
    bool nurseMode = false,
    List<PageRouteInfo>? children,
  }) : super(
         MessageCenterRoute.name,
         args: MessageCenterRouteArgs(key: key, nurseMode: nurseMode),
         initialChildren: children,
       );

  static const String name = 'MessageCenterRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MessageCenterRouteArgs>(
        orElse: () => const MessageCenterRouteArgs(),
      );
      return MessageCenterPage(key: args.key, nurseMode: args.nurseMode);
    },
  );
}

class MessageCenterRouteArgs {
  const MessageCenterRouteArgs({this.key, this.nurseMode = false});

  final Key? key;

  final bool nurseMode;

  @override
  String toString() {
    return 'MessageCenterRouteArgs{key: $key, nurseMode: $nurseMode}';
  }
}

/// generated route for
/// [NurseHomePage]
class NurseHomeRoute extends PageRouteInfo<void> {
  const NurseHomeRoute({List<PageRouteInfo>? children})
    : super(NurseHomeRoute.name, initialChildren: children);

  static const String name = 'NurseHomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NurseHomePage();
    },
  );
}

/// generated route for
/// [NurseIncomePage]
class NurseIncomeRoute extends PageRouteInfo<void> {
  const NurseIncomeRoute({List<PageRouteInfo>? children})
    : super(NurseIncomeRoute.name, initialChildren: children);

  static const String name = 'NurseIncomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NurseIncomePage();
    },
  );
}

/// generated route for
/// [NurseMessagePage]
class NurseMessageRoute extends PageRouteInfo<void> {
  const NurseMessageRoute({List<PageRouteInfo>? children})
    : super(NurseMessageRoute.name, initialChildren: children);

  static const String name = 'NurseMessageRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NurseMessagePage();
    },
  );
}

/// generated route for
/// [NurseProfileEditPage]
class NurseProfileEditRoute extends PageRouteInfo<void> {
  const NurseProfileEditRoute({List<PageRouteInfo>? children})
    : super(NurseProfileEditRoute.name, initialChildren: children);

  static const String name = 'NurseProfileEditRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NurseProfileEditPage();
    },
  );
}

/// generated route for
/// [NurseProfilePage]
class NurseProfileRoute extends PageRouteInfo<void> {
  const NurseProfileRoute({List<PageRouteInfo>? children})
    : super(NurseProfileRoute.name, initialChildren: children);

  static const String name = 'NurseProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NurseProfilePage();
    },
  );
}

/// generated route for
/// [NurseRegisterPage]
class NurseRegisterRoute extends PageRouteInfo<void> {
  const NurseRegisterRoute({List<PageRouteInfo>? children})
    : super(NurseRegisterRoute.name, initialChildren: children);

  static const String name = 'NurseRegisterRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NurseRegisterPage();
    },
  );
}

/// generated route for
/// [NurseTaskDetailPage]
class NurseTaskDetailRoute extends PageRouteInfo<NurseTaskDetailRouteArgs> {
  NurseTaskDetailRoute({
    Key? key,
    required int orderId,
    List<PageRouteInfo>? children,
  }) : super(
         NurseTaskDetailRoute.name,
         args: NurseTaskDetailRouteArgs(key: key, orderId: orderId),
         rawPathParams: {'orderId': orderId},
         initialChildren: children,
       );

  static const String name = 'NurseTaskDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<NurseTaskDetailRouteArgs>(
        orElse: () =>
            NurseTaskDetailRouteArgs(orderId: pathParams.getInt('orderId')),
      );
      return NurseTaskDetailPage(key: args.key, orderId: args.orderId);
    },
  );
}

class NurseTaskDetailRouteArgs {
  const NurseTaskDetailRouteArgs({this.key, required this.orderId});

  final Key? key;

  final int orderId;

  @override
  String toString() {
    return 'NurseTaskDetailRouteArgs{key: $key, orderId: $orderId}';
  }
}

/// generated route for
/// [NurseTaskPage]
class NurseTaskRoute extends PageRouteInfo<void> {
  const NurseTaskRoute({List<PageRouteInfo>? children})
    : super(NurseTaskRoute.name, initialChildren: children);

  static const String name = 'NurseTaskRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NurseTaskPage();
    },
  );
}

/// generated route for
/// [OrderDetailPage]
class OrderDetailRoute extends PageRouteInfo<OrderDetailRouteArgs> {
  OrderDetailRoute({
    Key? key,
    required String orderId,
    List<PageRouteInfo>? children,
  }) : super(
         OrderDetailRoute.name,
         args: OrderDetailRouteArgs(key: key, orderId: orderId),
         rawPathParams: {'orderId': orderId},
         initialChildren: children,
       );

  static const String name = 'OrderDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<OrderDetailRouteArgs>(
        orElse: () =>
            OrderDetailRouteArgs(orderId: pathParams.getString('orderId')),
      );
      return OrderDetailPage(key: args.key, orderId: args.orderId);
    },
  );
}

class OrderDetailRouteArgs {
  const OrderDetailRouteArgs({this.key, required this.orderId});

  final Key? key;

  final String orderId;

  @override
  String toString() {
    return 'OrderDetailRouteArgs{key: $key, orderId: $orderId}';
  }
}

/// generated route for
/// [OrderListPage]
class OrderListRoute extends PageRouteInfo<void> {
  const OrderListRoute({List<PageRouteInfo>? children})
    : super(OrderListRoute.name, initialChildren: children);

  static const String name = 'OrderListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const OrderListPage();
    },
  );
}

/// generated route for
/// [OrdersScreenPage]
class OrdersScreenRoute extends PageRouteInfo<void> {
  const OrdersScreenRoute({List<PageRouteInfo>? children})
    : super(OrdersScreenRoute.name, initialChildren: children);

  static const String name = 'OrdersScreenRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const OrdersScreenPage();
    },
  );
}

/// generated route for
/// [PaymentPage]
class PaymentRoute extends PageRouteInfo<PaymentRouteArgs> {
  PaymentRoute({
    Key? key,
    required int orderId,
    double? amount,
    List<PageRouteInfo>? children,
  }) : super(
         PaymentRoute.name,
         args: PaymentRouteArgs(key: key, orderId: orderId, amount: amount),
         rawPathParams: {'orderId': orderId},
         initialChildren: children,
       );

  static const String name = 'PaymentRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<PaymentRouteArgs>(
        orElse: () => PaymentRouteArgs(orderId: pathParams.getInt('orderId')),
      );
      return PaymentPage(
        key: args.key,
        orderId: args.orderId,
        amount: args.amount,
      );
    },
  );
}

class PaymentRouteArgs {
  const PaymentRouteArgs({this.key, required this.orderId, this.amount});

  final Key? key;

  final int orderId;

  final double? amount;

  @override
  String toString() {
    return 'PaymentRouteArgs{key: $key, orderId: $orderId, amount: $amount}';
  }
}

/// generated route for
/// [ProfileEditPage]
class ProfileEditRoute extends PageRouteInfo<void> {
  const ProfileEditRoute({List<PageRouteInfo>? children})
    : super(ProfileEditRoute.name, initialChildren: children);

  static const String name = 'ProfileEditRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfileEditPage();
    },
  );
}

/// generated route for
/// [ProfilePage]
class ProfileRoute extends PageRouteInfo<void> {
  const ProfileRoute({List<PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfilePage();
    },
  );
}

/// generated route for
/// [RealNameVerifyPage]
class RealNameVerifyRoute extends PageRouteInfo<void> {
  const RealNameVerifyRoute({List<PageRouteInfo>? children})
    : super(RealNameVerifyRoute.name, initialChildren: children);

  static const String name = 'RealNameVerifyRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RealNameVerifyPage();
    },
  );
}

/// generated route for
/// [RegisterPage]
class RegisterRoute extends PageRouteInfo<void> {
  const RegisterRoute({List<PageRouteInfo>? children})
    : super(RegisterRoute.name, initialChildren: children);

  static const String name = 'RegisterRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RegisterPage();
    },
  );
}

/// generated route for
/// [ServiceListPage]
class ServiceListRoute extends PageRouteInfo<void> {
  const ServiceListRoute({List<PageRouteInfo>? children})
    : super(ServiceListRoute.name, initialChildren: children);

  static const String name = 'ServiceListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ServiceListPage();
    },
  );
}

/// generated route for
/// [ServiceOrderPage]
class ServiceOrderRoute extends PageRouteInfo<ServiceOrderRouteArgs> {
  ServiceOrderRoute({
    Key? key,
    required int serviceId,
    List<PageRouteInfo>? children,
  }) : super(
         ServiceOrderRoute.name,
         args: ServiceOrderRouteArgs(key: key, serviceId: serviceId),
         rawPathParams: {'serviceId': serviceId},
         initialChildren: children,
       );

  static const String name = 'ServiceOrderRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ServiceOrderRouteArgs>(
        orElse: () =>
            ServiceOrderRouteArgs(serviceId: pathParams.getInt('serviceId')),
      );
      return ServiceOrderPage(key: args.key, serviceId: args.serviceId);
    },
  );
}

class ServiceOrderRouteArgs {
  const ServiceOrderRouteArgs({this.key, required this.serviceId});

  final Key? key;

  final int serviceId;

  @override
  String toString() {
    return 'ServiceOrderRouteArgs{key: $key, serviceId: $serviceId}';
  }
}

/// generated route for
/// [SplashPage]
class SplashRoute extends PageRouteInfo<void> {
  const SplashRoute({List<PageRouteInfo>? children})
    : super(SplashRoute.name, initialChildren: children);

  static const String name = 'SplashRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SplashPage();
    },
  );
}

/// generated route for
/// [UserHomePage]
class UserHomeRoute extends PageRouteInfo<void> {
  const UserHomeRoute({List<PageRouteInfo>? children})
    : super(UserHomeRoute.name, initialChildren: children);

  static const String name = 'UserHomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const UserHomePage();
    },
  );
}
