#import "DFRPrivateWrapper.h"
#import "DFRPrivateLoader.h"

@implementation NSTouchBarItem (DFRAccess)

- (void)addToSystemTray {
    [NSTouchBarItem addSystemTrayItem:self];
}

- (void)removeFromSystemTray {
    [NSTouchBarItem removeSystemTrayItem:self];
}

+ (void)setControlStripPresence:(BOOL)present for:(NSTouchBarItemIdentifier)identifier {
    DFRSetControlStripPresence(identifier, present);
}

- (void)setControlStripPresence:(BOOL)present {
    DFRSetControlStripPresence(self.identifier, present);
}

@end

@implementation NSTouchBar (DFRAccess)

- (void)presentAsSystemModalForItem:(NSTouchBarItem *)item {
    [self presentAsSystemModalForItemIdentifier:item.identifier];
}

- (void)presentAsSystemModalForItemIdentifier:(NSTouchBarItemIdentifier)identifier {
    if (@available(macOS 10.14, *)) {
        [NSTouchBar presentSystemModalTouchBar:self
                      systemTrayItemIdentifier:identifier];
    } else {
        [NSTouchBar presentSystemModalFunctionBar:self
                         systemTrayItemIdentifier:identifier];
    }
}

- (void)dismissSystemModal {
    if (@available(macOS 10.14, *)) {
        [NSTouchBar dismissSystemModalTouchBar:self];
    } else {
        [NSTouchBar dismissSystemModalFunctionBar:self];
    }
}

- (void)minimizeSystemModal {
    if (@available(macOS 10.14, *)) {
        [NSTouchBar minimizeSystemModalTouchBar:self];
    } else {
        [NSTouchBar minimizeSystemModalFunctionBar:self];
    }
}

+ (void)setSystemModalShowsCloseBoxWhenFrontMost:(BOOL)show {
    DFRSetSystemModalShowsCloseBox(show);
}

@end
