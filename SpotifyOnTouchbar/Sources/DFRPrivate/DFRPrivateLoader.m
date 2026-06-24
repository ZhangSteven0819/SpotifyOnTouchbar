#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "DFRPrivateHeader.h"

#define DFR_FOUNDATION_PATH "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation"
#define DFR_ELEMENT_SET_CONTROL_STRIP "DFRElementSetControlStripPresenceForIdentifier"
#define DFR_SYSTEM_MODAL_CLOSE_BOX "DFRSystemModalShowsCloseBoxWhenFrontMost"

static void (*_DFRElementSetControlStripPresenceForIdentifier)(NSTouchBarItemIdentifier, BOOL);
static void (*_DFRSystemModalShowsCloseBoxWhenFrontMost)(BOOL);

__attribute__((constructor))
static void DFRPrivateLoader(void) {
    void *handle = dlopen(DFR_FOUNDATION_PATH, RTLD_LAZY);
    if (handle) {
        _DFRElementSetControlStripPresenceForIdentifier = dlsym(handle, DFR_ELEMENT_SET_CONTROL_STRIP);
        _DFRSystemModalShowsCloseBoxWhenFrontMost = dlsym(handle, DFR_SYSTEM_MODAL_CLOSE_BOX);
        dlclose(handle);
    }
}

// Public wrapper functions

void DFRSetControlStripPresence(NSTouchBarItemIdentifier identifier, BOOL present) {
    if (_DFRElementSetControlStripPresenceForIdentifier) {
        _DFRElementSetControlStripPresenceForIdentifier(identifier, present);
    }
}

void DFRSetSystemModalShowsCloseBox(BOOL show) {
    if (_DFRSystemModalShowsCloseBoxWhenFrontMost) {
        _DFRSystemModalShowsCloseBoxWhenFrontMost(show);
    }
}
