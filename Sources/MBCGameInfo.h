/*
	File:		MBCGameInfo.h
	Contains:	Managing information about the current game
	Copyright:	� 2002-2005 Apple Computer, Inc. All rights reserved.

	IMPORTANT: This Apple software is supplied to you by Apple Computer,
	Inc.  ("Apple") in consideration of your agreement to the following
	terms, and your use, installation, modification or redistribution of
	this Apple software constitutes acceptance of these terms.  If you do
	not agree with these terms, please do not use, install, modify or
	redistribute this Apple software.
	
	In consideration of your agreement to abide by the following terms,
	and subject to these terms, Apple grants you a personal, non-exclusive
	license, under Apple's copyrights in this original Apple software (the
	"Apple Software"), to use, reproduce, modify and redistribute the
	Apple Software, with or without modifications, in source and/or binary
	forms; provided that if you redistribute the Apple Software in its
	entirety and without modifications, you must retain this notice and
	the following text and disclaimers in all such redistributions of the
	Apple Software.  Neither the name, trademarks, service marks or logos
	of Apple Computer, Inc. may be used to endorse or promote products
	derived from the Apple Software without specific prior written
	permission from Apple.  Except as expressly stated in this notice, no
	other rights or licenses, express or implied, are granted by Apple
	herein, including but not limited to any patent rights that may be
	infringed by your derivative works or by other works in which the
	Apple Software may be incorporated.
	
	The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
	MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
	THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND
	FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS
	USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
	
	IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT,
	INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
	PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
	PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE,
	REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE,
	HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING
	NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
	ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Cocoa/Cocoa.h>

#import "MBCBoard.h"

@class MBCBoard;

@interface MBCGameInfo : NSObject
{
	IBOutlet id		fInfoWindow;
	IBOutlet id		fMainWindow;
	IBOutlet id		fShowMoveInTitle;
	IBOutlet id		fEditSheet;
	IBOutlet id		fMatchup;
	IBOutlet id		fWhite;
	IBOutlet id		fBlack;
	IBOutlet id		fCity;
	IBOutlet id		fCountry;
	IBOutlet id		fEvent;
	IBOutlet id		fMoveList;

	MBCBoard *		fBoard;
	MBCSide			fHuman;
	bool			fTitleNeedsUpdate;
	bool			fSetInfo;
	int				fRows;
	MBCSide			fSideToPlay;
	NSString *		fOutcome;
	NSString *		fWhiteName;
	NSString *		fBlackName;
	NSString * 		fStartDate;
	NSString * 		fStartTime;
	NSString * 		fResult;
}

- (NSDictionary *)getInfo;
- (void)setInfo:(NSDictionary *)dict;
- (void)startGame:(MBCVariant)variant playing:(MBCSide)sideToPlay;
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (IBAction) editInfo:(id)sender;
- (IBAction) cancelInfo:(id)sender;
- (IBAction) updateInfo:(id)sender;
- (IBAction) updateTitle:(id)sender;
+ (void) parseName:(NSString *)fullName intoFirst:(NSString **)firstName
			  last:(NSString **)lastName;
- (NSString *)pgnHeader;
- (NSString *)pgnResult;

@end

// Local Variables:
// mode:ObjC
// End:
