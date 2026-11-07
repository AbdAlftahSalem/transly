// The screens of the example shop. Every one of the 168 keys in
// lib/l10n/app_en.arb is used somewhere below, so `transly check` reports no
// unused keys. Generated once by a script, then kept by hand.
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'l10n_extension.dart';

/// The "app" strings.
List<Widget> appTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.appTitle)),
    ListTile(title: Text(l10n.tagline)),
  ];
}

/// The "onboarding" strings.
List<Widget> onboardingTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.onboardingTitle1)),
    ListTile(title: Text(l10n.onboardingBody1)),
    ListTile(title: Text(l10n.onboardingTitle2)),
    ListTile(title: Text(l10n.onboardingBody2)),
    ListTile(title: Text(l10n.onboardingTitle3)),
    ListTile(title: Text(l10n.onboardingBody3)),
  ];
}

/// The "auth" strings.
List<Widget> authTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.signIn)),
    ListTile(title: Text(l10n.signUp)),
    ListTile(title: Text(l10n.signOut)),
    ListTile(title: Text(l10n.email)),
    ListTile(title: Text(l10n.password)),
    ListTile(title: Text(l10n.forgotPassword)),
    ListTile(title: Text(l10n.resetPassword)),
    ListTile(title: Text(l10n.createAccount)),
    ListTile(title: Text(l10n.alreadyHaveAccount)),
    ListTile(title: Text(l10n.noAccount)),
    ListTile(title: Text(l10n.continueWithGoogle)),
    ListTile(title: Text(l10n.continueWithApple)),
    ListTile(title: Text(l10n.termsAgreement)),
    ListTile(title: Text(l10n.welcomeBack('Sara'))),
  ];
}

/// The "nav" strings.
List<Widget> navTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.navHome)),
    ListTile(title: Text(l10n.navCategories)),
    ListTile(title: Text(l10n.navCart)),
    ListTile(title: Text(l10n.navOrders)),
    ListTile(title: Text(l10n.navProfile)),
  ];
}

/// The "home" strings.
List<Widget> homeTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.homeGreeting('Sara'))),
    ListTile(title: Text(l10n.searchHint)),
    ListTile(title: Text(l10n.featured)),
    ListTile(title: Text(l10n.newArrivals)),
    ListTile(title: Text(l10n.bestSellers)),
    ListTile(title: Text(l10n.seeAll)),
    ListTile(title: Text(l10n.flashSaleEndsIn(3, 3))),
    ListTile(title: Text(l10n.freeShippingOver(r'\$50'))),
  ];
}

/// The "categories" strings.
List<Widget> categoriesTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.categoryElectronics)),
    ListTile(title: Text(l10n.categoryFashion)),
    ListTile(title: Text(l10n.categoryHomeKitchen)),
    ListTile(title: Text(l10n.categoryBeauty)),
    ListTile(title: Text(l10n.categorySports)),
    ListTile(title: Text(l10n.categoryToys)),
    ListTile(title: Text(l10n.categoryBooks)),
    ListTile(title: Text(l10n.categoryGrocery)),
    ListTile(title: Text(l10n.categoryGarden)),
    ListTile(title: Text(l10n.categoryAutomotive)),
    ListTile(title: Text(l10n.categoryHealth)),
    ListTile(title: Text(l10n.categoryPets)),
    ListTile(title: Text(l10n.categoryMusic)),
    ListTile(title: Text(l10n.categoryOfficeSupplies)),
    ListTile(title: Text(l10n.categoryJewelry)),
    ListTile(title: Text(l10n.categoryBabyCare)),
  ];
}

/// The "product" strings.
List<Widget> productTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.addToCart)),
    ListTile(title: Text(l10n.buyNow)),
    ListTile(title: Text(l10n.inStock)),
    ListTile(title: Text(l10n.outOfStock)),
    ListTile(title: Text(l10n.onlyLeft(3))),
    ListTile(title: Text(l10n.reviewsCount(3))),
    ListTile(title: Text(l10n.ratingOutOfFive('4.5'))),
    ListTile(title: Text(l10n.productDescription)),
    ListTile(title: Text(l10n.specifications)),
    ListTile(title: Text(l10n.size)),
    ListTile(title: Text(l10n.color)),
    ListTile(title: Text(l10n.quantity)),
    ListTile(title: Text(l10n.shareProduct)),
    ListTile(title: Text(l10n.priceWithDiscount(r'\$19', r'\$25'))),
  ];
}

/// The "cart" strings.
List<Widget> cartTiles(BuildContext context) {
  final l10n = context.l10n;
  return [
    ListTile(title: Text(l10n.cartTitle)),
    ListTile(title: Text(l10n.cartEmpty)),
    ListTile(title: Text(l10n.cartItems(3))),
    ListTile(title: Text(l10n.subtotal)),
    ListTile(title: Text(l10n.shipping)),
    ListTile(title: Text(l10n.tax)),
    ListTile(title: Text(l10n.total)),
    ListTile(title: Text(l10n.removeItem)),
    ListTile(title: Text(l10n.undo)),
    ListTile(title: Text(l10n.applyCoupon)),
    ListTile(title: Text(l10n.couponApplied('SAVE10'))),
    ListTile(title: Text(l10n.proceedToCheckout)),
  ];
}

/// The "checkout" strings.
List<Widget> checkoutTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.checkoutTitle)),
    ListTile(title: Text(l10n.shippingAddress)),
    ListTile(title: Text(l10n.paymentMethod)),
    ListTile(title: Text(l10n.cardNumber)),
    ListTile(title: Text(l10n.expiryDate)),
    ListTile(title: Text(l10n.securityCode)),
    ListTile(title: Text(l10n.placeOrder)),
    ListTile(title: Text(l10n.orderPlaced)),
    ListTile(title: Text(l10n.orderNumber('#1042'))),
    ListTile(title: Text(l10n.estimatedDelivery('Nov 12'))),
    ListTile(title: Text(l10n.cashOnDelivery)),
    ListTile(title: Text(l10n.addNewAddress)),
    ListTile(title: Text(l10n.deliveryInstructions)),
    ListTile(title: Text(l10n.paymentFailed)),
  ];
}

/// The "orders" strings.
List<Widget> ordersTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.ordersTitle)),
    ListTile(title: Text(l10n.noOrders)),
    ListTile(title: Text(l10n.orderStatusPending)),
    ListTile(title: Text(l10n.orderStatusShipped)),
    ListTile(title: Text(l10n.orderStatusDelivered)),
    ListTile(title: Text(l10n.orderStatusCancelled)),
    ListTile(title: Text(l10n.trackOrder)),
    ListTile(title: Text(l10n.orderPlacedOn('Nov 12'))),
    ListTile(title: Text(l10n.itemsInOrder(3))),
    ListTile(title: Text(l10n.reorder)),
  ];
}

/// The "profile" strings.
List<Widget> profileTiles(BuildContext context) {
  final l10n = context.l10n;
  return [
    ListTile(title: Text(l10n.profileTitle)),
    ListTile(title: Text(l10n.editProfile)),
    ListTile(title: Text(l10n.fullName)),
    ListTile(title: Text(l10n.phoneNumber)),
    ListTile(title: Text(l10n.addresses)),
    ListTile(title: Text(l10n.wishlist)),
    ListTile(title: Text(l10n.wishlistCount(3))),
    ListTile(title: Text(l10n.memberSince('2021'))),
    ListTile(title: Text(l10n.inviteFriends)),
    ListTile(title: Text(l10n.inviteReward(r'\$50'))),
  ];
}

/// The "settings" strings.
List<Widget> settingsTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.settingsTitle)),
    ListTile(title: Text(l10n.language)),
    ListTile(title: Text(l10n.darkMode)),
    ListTile(title: Text(l10n.notificationsSetting)),
    ListTile(title: Text(l10n.pushNotifications)),
    ListTile(title: Text(l10n.emailNotifications)),
    ListTile(title: Text(l10n.currency)),
    ListTile(title: Text(l10n.privacyPolicy)),
    ListTile(title: Text(l10n.termsOfService)),
    ListTile(title: Text(l10n.helpCenter)),
    ListTile(title: Text(l10n.contactUs)),
    ListTile(title: Text(l10n.rateApp)),
    ListTile(title: Text(l10n.appVersion('1.0.0'))),
    ListTile(title: Text(l10n.deleteAccount)),
  ];
}

/// The "notifications" strings.
List<Widget> notificationsTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.notificationsTitle)),
    ListTile(title: Text(l10n.noNotifications)),
    ListTile(title: Text(l10n.markAllRead)),
    ListTile(title: Text(l10n.newMessagesFrom(3, 'Sara'))),
    ListTile(title: Text(l10n.priceDropAlert('AirPods'))),
    ListTile(title: Text(l10n.orderShippedNotice('#1042'))),
  ];
}

/// The "errors" strings.
List<Widget> errorsTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.errorGeneric)),
    ListTile(title: Text(l10n.errorNetwork)),
    ListTile(title: Text(l10n.errorTimeout)),
    ListTile(title: Text(l10n.errorServer)),
    ListTile(title: Text(l10n.errorInvalidEmail)),
    ListTile(title: Text(l10n.errorPasswordTooShort(3))),
    ListTile(title: Text(l10n.errorRequiredField)),
    ListTile(title: Text(l10n.errorPaymentDeclined)),
    ListTile(title: Text(l10n.retry)),
    ListTile(title: Text(l10n.sessionExpired)),
  ];
}

/// The "common" strings.
List<Widget> commonTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.ok)),
    ListTile(title: Text(l10n.cancel)),
    ListTile(title: Text(l10n.save)),
    ListTile(title: Text(l10n.delete)),
    ListTile(title: Text(l10n.edit)),
    ListTile(title: Text(l10n.close)),
    ListTile(title: Text(l10n.confirm)),
    ListTile(title: Text(l10n.yes)),
    ListTile(title: Text(l10n.no)),
    ListTile(title: Text(l10n.loading)),
    ListTile(title: Text(l10n.done)),
    ListTile(title: Text(l10n.back)),
    ListTile(title: Text(l10n.next)),
    ListTile(title: Text(l10n.skip)),
  ];
}

/// The "misc" strings.
List<Widget> miscTiles(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ListTile(title: Text(l10n.genderGreeting('female', 'Sara'))),
    ListTile(title: Text(l10n.itemsSelected(3))),
    ListTile(title: Text(l10n.daysLeft(3))),
    ListTile(title: Text(l10n.minutesAgo(3))),
    ListTile(title: Text(l10n.followers(3))),
    ListTile(title: Text(context.l10n.lastSeen('5 min ago'))),
  ];
}

/// The "days" strings.
List<Widget> daysTiles(BuildContext context) {
  final l10n = context.l10n;
  return [
    ListTile(title: Text(l10n.monday)),
    ListTile(title: Text(l10n.tuesday)),
    ListTile(title: Text(l10n.wednesday)),
    ListTile(title: Text(l10n.thursday)),
    ListTile(title: Text(l10n.friday)),
    ListTile(title: Text(l10n.saturday)),
    ListTile(title: Text(l10n.sunday)),
  ];
}
