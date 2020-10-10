#import "RNPermissionHandlerNotifications.h"

@import UserNotifications;
@import UIKit;

@interface RNPermissionHandlerNotifications()

@property (nonatomic, strong) void (^resolve)(RNPermissionStatus status, NSDictionary * _Nonnull settings);
@property (nonatomic, strong) void (^reject)(NSError *error);

@end

@implementation RNPermissionHandlerNotifications

+ (NSString * _Nonnull)handlerUniqueId {
  return @"ios.permission.NOTIFICATIONS";
}

- (void)checkWithResolver:(void (^ _Nonnull)(RNPermissionStatus status, NSDictionary * _Nonnull settings))resolve
                 rejecter:(void (^ _Nonnull)(NSError * _Nonnull error))reject {
  [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
    NSMutableDictionary *result = [NSMutableDictionary new];

    bool alert = settings.alertSetting == UNNotificationSettingEnabled;
    bool badge = settings.badgeSetting == UNNotificationSettingEnabled;
    bool sound = settings.soundSetting == UNNotificationSettingEnabled;
    bool lockScreen = settings.lockScreenSetting == UNNotificationSettingEnabled;
    bool carPlay = settings.carPlaySetting == UNNotificationSettingEnabled;
    bool notificationCenter = settings.notificationCenterSetting == UNNotificationSettingEnabled;

    if (settings.alertSetting != UNNotificationSettingNotSupported)
      [result setValue:@(alert) forKey:@"alert"];
    if (settings.badgeSetting != UNNotificationSettingNotSupported)
      [result setValue:@(badge) forKey:@"badge"];
    if (settings.soundSetting != UNNotificationSettingNotSupported)
      [result setValue:@(sound) forKey:@"sound"];
    if (settings.lockScreenSetting != UNNotificationSettingNotSupported)
      [result setValue:@(lockScreen) forKey:@"lockScreen"];
    if (settings.carPlaySetting != UNNotificationSettingNotSupported)
      [result setValue:@(carPlay) forKey:@"carPlay"];
    if (settings.notificationCenterSetting != UNNotificationSettingNotSupported)
      [result setValue:@(notificationCenter) forKey:@"notificationCenter"];

    if (@available(iOS 12.0, *)) {
      bool criticalAlert = settings.criticalAlertSetting == UNNotificationSettingEnabled;

      if (settings.criticalAlertSetting != UNNotificationSettingNotSupported)
        [result setValue:@(criticalAlert) forKey:@"criticalAlert"];
    }

    switch (settings.authorizationStatus) {
      case UNAuthorizationStatusNotDetermined:
        return resolve(RNPermissionStatusNotDetermined, result);
      case UNAuthorizationStatusDenied:
        return resolve(RNPermissionStatusDenied, result);
      case UNAuthorizationStatusAuthorized:
      case UNAuthorizationStatusEphemeral: // TODO: Handle Ephemeral status
      case UNAuthorizationStatusProvisional: // TODO: Handle Provisional status
        return resolve(RNPermissionStatusAuthorized, result);
    }
  }];
}

- (void)requestWithResolver:(void (^ _Nonnull)(RNPermissionStatus status, NSDictionary * _Nonnull settings))resolve
                   rejecter:(void (^ _Nonnull)(NSError * _Nonnull error))reject
                    options:(NSArray<NSString *> * _Nonnull)options {
  _resolve = resolve;
  _reject = reject;

  bool alert = [options containsObject:@"alert"];
  bool badge = [options containsObject:@"badge"];
  bool sound = [options containsObject:@"sound"];
  bool criticalAlert = [options containsObject:@"criticalAlert"];
  bool carPlay = [options containsObject:@"carPlay"];
  bool provisional = [options containsObject:@"provisional"];

  UNAuthorizationOptions types = UNAuthorizationOptionNone;

  if (alert) types += UNAuthorizationOptionAlert;
  if (badge) types += UNAuthorizationOptionBadge;
  if (sound) types += UNAuthorizationOptionSound;
  if (carPlay) types += UNAuthorizationOptionCarPlay;

  if (@available(iOS 12.0, *)) {
    if (criticalAlert) types += UNAuthorizationOptionCriticalAlert;
    if (provisional) types += UNAuthorizationOptionProvisional;
  }

  if (!alert &&
      !badge &&
      !sound &&
      !criticalAlert &&
      !carPlay &&
      !provisional) {
    types += UNAuthorizationOptionAlert;
    types += UNAuthorizationOptionBadge;
    types += UNAuthorizationOptionSound;
  }

  [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:types
                                                                      completionHandler:^(BOOL granted, NSError * _Nullable error) {
    if (error != nil) {
      return reject(error);
    }

    if (granted) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] registerForRemoteNotifications];
      });
    }

    [RNPermissions flagAsRequested:[[self class] handlerUniqueId]];
    [self checkWithResolver:self->_resolve rejecter:self->_reject];
  }];
}

@end
