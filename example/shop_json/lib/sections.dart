// The screens of the example shop. Every key in assets/translations/ar.json is
// used below, so `transly check` reports no unused keys.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The "app" strings.
List<Widget> appTiles(BuildContext context) {
  return [
    ListTile(title: Text('app.appTitle'.tr())),
    ListTile(title: Text(tr('app.tagline'))),
  ];
}

/// The "onboarding" strings.
List<Widget> onboardingTiles(BuildContext context) {
  return [
    ListTile(title: Text('onboarding.onboardingTitle1'.tr())),
    ListTile(title: Text(tr('onboarding.onboardingBody1'))),
    ListTile(title: Text(context.tr('onboarding.onboardingTitle2'))),
    ListTile(title: Text('onboarding.onboardingBody2'.tr())),
    ListTile(title: Text(tr('onboarding.onboardingTitle3'))),
    ListTile(title: Text(context.tr('onboarding.onboardingBody3'))),
  ];
}

/// The "auth" strings.
List<Widget> authTiles(BuildContext context) {
  return [
    ListTile(title: Text('auth.signIn'.tr())),
    ListTile(title: Text(tr('auth.signUp'))),
    ListTile(title: Text(context.tr('auth.signOut'))),
    ListTile(title: Text('auth.email'.tr())),
    ListTile(title: Text(tr('auth.password'))),
    ListTile(title: Text(context.tr('auth.forgotPassword'))),
    ListTile(title: Text('auth.resetPassword'.tr())),
    ListTile(title: Text(tr('auth.createAccount'))),
    ListTile(title: Text(context.tr('auth.alreadyHaveAccount'))),
    ListTile(title: Text('auth.noAccount'.tr())),
    ListTile(title: Text(tr('auth.continueWithGoogle'))),
    ListTile(title: Text(context.tr('auth.continueWithApple'))),
    ListTile(title: Text('auth.termsAgreement'.tr())),
    ListTile(title: Text('auth.welcomeBack'.tr(namedArgs: {'name': 'Sara'}))),
  ];
}

/// The "nav" strings.
List<Widget> navTiles(BuildContext context) {
  return [
    ListTile(title: Text('nav.navHome'.tr())),
    ListTile(title: Text(tr('nav.navCategories'))),
    ListTile(title: Text(context.tr('nav.navCart'))),
    ListTile(title: Text('nav.navOrders'.tr())),
    ListTile(title: Text(tr('nav.navProfile'))),
  ];
}

/// The "home" strings.
List<Widget> homeTiles(BuildContext context) {
  return [
    ListTile(title: Text('home.homeGreeting'.tr(namedArgs: {'name': 'Sara'}))),
    ListTile(title: Text(tr('home.searchHint'))),
    ListTile(title: Text(context.tr('home.featured'))),
    ListTile(title: Text('home.newArrivals'.tr())),
    ListTile(title: Text(tr('home.bestSellers'))),
    ListTile(title: Text(context.tr('home.seeAll'))),
    ListTile(title: Text('home.flashSaleEndsIn'.tr(namedArgs: {'hours': '3', 'minutes': '3'}))),
    ListTile(title: Text('home.freeShippingOver'.tr(namedArgs: {'amount': '\$50'}))),
  ];
}

/// The "categories" strings.
List<Widget> categoriesTiles(BuildContext context) {
  return [
    ListTile(title: Text('categories.categoryElectronics'.tr())),
    ListTile(title: Text(tr('categories.categoryFashion'))),
    ListTile(title: Text(context.tr('categories.categoryHomeKitchen'))),
    ListTile(title: Text('categories.categoryBeauty'.tr())),
    ListTile(title: Text(tr('categories.categorySports'))),
    ListTile(title: Text(context.tr('categories.categoryToys'))),
    ListTile(title: Text('categories.categoryBooks'.tr())),
    ListTile(title: Text(tr('categories.categoryGrocery'))),
    ListTile(title: Text(context.tr('categories.categoryGarden'))),
    ListTile(title: Text('categories.categoryAutomotive'.tr())),
    ListTile(title: Text(tr('categories.categoryHealth'))),
    ListTile(title: Text(context.tr('categories.categoryPets'))),
    ListTile(title: Text('categories.categoryMusic'.tr())),
    ListTile(title: Text(tr('categories.categoryOfficeSupplies'))),
    ListTile(title: Text(context.tr('categories.categoryJewelry'))),
    ListTile(title: Text('categories.categoryBabyCare'.tr())),
  ];
}

/// The "product" strings.
List<Widget> productTiles(BuildContext context) {
  return [
    ListTile(title: Text('product.addToCart'.tr())),
    ListTile(title: Text(tr('product.buyNow'))),
    ListTile(title: Text(context.tr('product.inStock'))),
    ListTile(title: Text('product.outOfStock'.tr())),
    ListTile(title: Text('product.onlyLeft'.plural(3))),
    ListTile(title: Text('product.reviewsCount'.plural(3))),
    ListTile(title: Text('product.ratingOutOfFive'.tr(namedArgs: {'rating': '4.5'}))),
    ListTile(title: Text(tr('product.productDescription'))),
    ListTile(title: Text(context.tr('product.specifications'))),
    ListTile(title: Text('product.size'.tr())),
    ListTile(title: Text(tr('product.color'))),
    ListTile(title: Text(context.tr('product.quantity'))),
    ListTile(title: Text('product.shareProduct'.tr())),
    ListTile(title: Text('product.priceWithDiscount'.tr(namedArgs: {'price': '\$19', 'oldPrice': '\$25'}))),
  ];
}

/// The "cart" strings.
List<Widget> cartTiles(BuildContext context) {
  return [
    ListTile(title: Text('cart.cartTitle'.tr())),
    ListTile(title: Text(tr('cart.cartEmpty'))),
    ListTile(title: Text('cart.cartItems'.plural(3))),
    ListTile(title: Text('cart.subtotal'.tr())),
    ListTile(title: Text(tr('cart.shipping'))),
    ListTile(title: Text(context.tr('cart.tax'))),
    ListTile(title: Text('cart.total'.tr())),
    ListTile(title: Text(tr('cart.removeItem'))),
    ListTile(title: Text(context.tr('cart.undo'))),
    ListTile(title: Text('cart.applyCoupon'.tr())),
    ListTile(title: Text('cart.couponApplied'.tr(namedArgs: {'code': 'SAVE10'}))),
    ListTile(title: Text(context.tr('cart.proceedToCheckout'))),
  ];
}

/// The "checkout" strings.
List<Widget> checkoutTiles(BuildContext context) {
  return [
    ListTile(title: Text('checkout.checkoutTitle'.tr())),
    ListTile(title: Text(tr('checkout.shippingAddress'))),
    ListTile(title: Text(context.tr('checkout.paymentMethod'))),
    ListTile(title: Text('checkout.cardNumber'.tr())),
    ListTile(title: Text(tr('checkout.expiryDate'))),
    ListTile(title: Text(context.tr('checkout.securityCode'))),
    ListTile(title: Text('checkout.placeOrder'.tr())),
    ListTile(title: Text(tr('checkout.orderPlaced'))),
    ListTile(title: Text('checkout.orderNumber'.tr(namedArgs: {'number': '#1042'}))),
    ListTile(title: Text('checkout.estimatedDelivery'.tr(namedArgs: {'date': 'Nov 12'}))),
    ListTile(title: Text(tr('checkout.cashOnDelivery'))),
    ListTile(title: Text(context.tr('checkout.addNewAddress'))),
    ListTile(title: Text('checkout.deliveryInstructions'.tr())),
    ListTile(title: Text(tr('checkout.paymentFailed'))),
  ];
}

/// The "orders" strings.
List<Widget> ordersTiles(BuildContext context) {
  return [
    ListTile(title: Text('orders.ordersTitle'.tr())),
    ListTile(title: Text(tr('orders.noOrders'))),
    ListTile(title: Text(context.tr('orders.orderStatusPending'))),
    ListTile(title: Text('orders.orderStatusShipped'.tr())),
    ListTile(title: Text(tr('orders.orderStatusDelivered'))),
    ListTile(title: Text(context.tr('orders.orderStatusCancelled'))),
    ListTile(title: Text('orders.trackOrder'.tr())),
    ListTile(title: Text('orders.orderPlacedOn'.tr(namedArgs: {'date': 'Nov 12'}))),
    ListTile(title: Text('orders.itemsInOrder'.plural(3))),
    ListTile(title: Text('orders.reorder'.tr())),
  ];
}

/// The "profile" strings.
List<Widget> profileTiles(BuildContext context) {
  return [
    ListTile(title: Text('profile.profileTitle'.tr())),
    ListTile(title: Text(tr('profile.editProfile'))),
    ListTile(title: Text(context.tr('profile.fullName'))),
    ListTile(title: Text('profile.phoneNumber'.tr())),
    ListTile(title: Text(tr('profile.addresses'))),
    ListTile(title: Text(context.tr('profile.wishlist'))),
    ListTile(title: Text('profile.wishlistCount'.plural(3))),
    ListTile(title: Text('profile.memberSince'.tr(namedArgs: {'year': '2021'}))),
    ListTile(title: Text(context.tr('profile.inviteFriends'))),
    ListTile(title: Text('profile.inviteReward'.tr(namedArgs: {'amount': '\$50'}))),
  ];
}

/// The "settings" strings.
List<Widget> settingsTiles(BuildContext context) {
  return [
    ListTile(title: Text('settings.settingsTitle'.tr())),
    ListTile(title: Text(tr('settings.language'))),
    ListTile(title: Text(context.tr('settings.darkMode'))),
    ListTile(title: Text('settings.notificationsSetting'.tr())),
    ListTile(title: Text(tr('settings.pushNotifications'))),
    ListTile(title: Text(context.tr('settings.emailNotifications'))),
    ListTile(title: Text('settings.currency'.tr())),
    ListTile(title: Text(tr('settings.privacyPolicy'))),
    ListTile(title: Text(context.tr('settings.termsOfService'))),
    ListTile(title: Text('settings.helpCenter'.tr())),
    ListTile(title: Text(tr('settings.contactUs'))),
    ListTile(title: Text(context.tr('settings.rateApp'))),
    ListTile(title: Text('settings.appVersion'.tr(namedArgs: {'version': '1.0.0'}))),
    ListTile(title: Text(tr('settings.deleteAccount'))),
  ];
}

/// The "notifications" strings.
List<Widget> notificationsTiles(BuildContext context) {
  return [
    ListTile(title: Text('notifications.notificationsTitle'.tr())),
    ListTile(title: Text(tr('notifications.noNotifications'))),
    ListTile(title: Text(context.tr('notifications.markAllRead'))),
    ListTile(title: Text('notifications.newMessagesFrom'.plural(3, namedArgs: {'name': 'Sara'}))),
    ListTile(title: Text('notifications.priceDropAlert'.tr(namedArgs: {'product': 'AirPods'}))),
    ListTile(title: Text('notifications.orderShippedNotice'.tr(namedArgs: {'orderId': '#1042'}))),
  ];
}

/// The "errors" strings.
List<Widget> errorsTiles(BuildContext context) {
  return [
    ListTile(title: Text('errors.errorGeneric'.tr())),
    ListTile(title: Text(tr('errors.errorNetwork'))),
    ListTile(title: Text(context.tr('errors.errorTimeout'))),
    ListTile(title: Text('errors.errorServer'.tr())),
    ListTile(title: Text(tr('errors.errorInvalidEmail'))),
    ListTile(title: Text('errors.errorPasswordTooShort'.tr(namedArgs: {'min': '3'}))),
    ListTile(title: Text('errors.errorRequiredField'.tr())),
    ListTile(title: Text(tr('errors.errorPaymentDeclined'))),
    ListTile(title: Text(context.tr('errors.retry'))),
    ListTile(title: Text('errors.sessionExpired'.tr())),
  ];
}

/// The "common" strings.
List<Widget> commonTiles(BuildContext context) {
  return [
    ListTile(title: Text('common.ok'.tr())),
    ListTile(title: Text(tr('common.cancel'))),
    ListTile(title: Text(context.tr('common.save'))),
    ListTile(title: Text('common.delete'.tr())),
    ListTile(title: Text(tr('common.edit'))),
    ListTile(title: Text(context.tr('common.close'))),
    ListTile(title: Text('common.confirm'.tr())),
    ListTile(title: Text(tr('common.yes'))),
    ListTile(title: Text(context.tr('common.no'))),
    ListTile(title: Text('common.loading'.tr())),
    ListTile(title: Text(tr('common.done'))),
    ListTile(title: Text(context.tr('common.back'))),
    ListTile(title: Text('common.next'.tr())),
    ListTile(title: Text(tr('common.skip'))),
  ];
}

/// The "misc" strings.
List<Widget> miscTiles(BuildContext context) {
  return [
    ListTile(title: Text('misc.genderGreeting'.tr(gender: 'female', namedArgs: {'name': 'Sara'}))),
    ListTile(title: Text('misc.itemsSelected'.plural(3))),
    ListTile(title: Text('misc.daysLeft'.plural(3))),
    ListTile(title: Text('misc.minutesAgo'.plural(3))),
    ListTile(title: Text('misc.followers'.plural(3))),
    ListTile(title: Text('misc.lastSeen'.tr(namedArgs: {'time': '5 min ago'}))),
  ];
}

/// The "days" strings.
List<Widget> daysTiles(BuildContext context) {
  return [
    ListTile(title: Text('days.monday'.tr())),
    ListTile(title: Text(tr('days.tuesday'))),
    ListTile(title: Text(context.tr('days.wednesday'))),
    ListTile(title: Text('days.thursday'.tr())),
    ListTile(title: Text(tr('days.friday'))),
    ListTile(title: Text(context.tr('days.saturday'))),
    ListTile(title: Text('days.sunday'.tr())),
  ];
}
