#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTouchBarItem (DFRAccess)

- (void)addToSystemTray;
- (void)removeFromSystemTray;
+ (void)setControlStripPresence:(BOOL)present for:(NSTouchBarItemIdentifier)identifier;
- (void)setControlStripPresence:(BOOL)present;

@end

@interface NSTouchBar (DFRAccess)

- (void)presentAsSystemModalForItem:(NSTouchBarItem *)item;
- (void)dismissSystemModal;
- (void)minimizeSystemModal;
+ (void)setSystemModalShowsCloseBoxWhenFrontMost:(BOOL)show;

@end

NS_ASSUME_NONNULL_END
