#import <TargetConditionals.h>
#import <UIKit/UIKit.h>

#include <stdbool.h>

bool SDL_IsIPad(void) {
	return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

bool SDL_IsAppleTV(void) {
	return TARGET_OS_TV;
}
