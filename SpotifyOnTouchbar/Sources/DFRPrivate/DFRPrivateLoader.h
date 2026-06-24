#ifndef DFRPrivateLoader_h
#define DFRPrivateLoader_h

#import <Cocoa/Cocoa.h>

// Public wrapper functions (defined in DFRPrivateLoader.m)
void DFRSetControlStripPresence(NSTouchBarItemIdentifier identifier, BOOL present);
void DFRSetSystemModalShowsCloseBox(BOOL show);

#endif
