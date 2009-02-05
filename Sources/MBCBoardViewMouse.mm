/*
	File:		MBCBoardViewMouse.mm
	Contains:	Handle mouse coordinate transformations
	Version:	1.0
	Copyright:	� 2002 by Apple Computer, Inc., all rights reserved.

	File Ownership:

		DRI:				Matthias Neeracher    x43683

	Writers:

		(MN)	Matthias Neeracher

	Change History (most recent first):

		$Log: MBCBoardViewMouse.mm,v $
		Revision 1.21  2007/03/02 23:06:00  neerache
		<rdar://problem/4038207> Allow the user to type in a move in Chess
		
		Revision 1.20  2004/09/08 00:35:24  neerache
		Reduce square sizes to avoid navigation ambiguities
		
		Revision 1.19  2004/08/16 07:50:55  neerache
		Support accessibility
		
		Revision 1.18  2003/07/18 22:14:26  neerache
		Disable pondering during drag to improve interactive performance (RADAR 2736549)
		
		Revision 1.17  2003/07/14 23:21:49  neerache
		Move promotion defaults into MBCBoard
		
		Revision 1.16  2003/07/07 08:47:54  neerache
		Switch to textured main window
		
		Revision 1.15  2003/06/18 21:55:17  neerache
		More (mostly unsuccessful) tweaking of floating windows
		
		Revision 1.14  2003/06/05 08:31:26  neerache
		Added Tuner
		
		Revision 1.13  2003/06/05 00:14:37  neerache
		Reduce excessive threshold
		
		Revision 1.12  2003/06/04 23:14:05  neerache
		Neater manipulation widget; remove obsolete graphics options
		
		Revision 1.11  2003/06/04 09:25:47  neerache
		New and improved board manipulation metaphor
		
		Revision 1.10  2003/06/02 05:44:48  neerache
		Implement direct board manipulation
		
		Revision 1.9  2003/05/24 20:28:27  neerache
		Address race conditions between ploayer and engine
		
		Revision 1.8  2003/05/02 01:16:33  neerache
		Simplify drawing methods
		
		Revision 1.7  2003/04/28 22:11:45  neerache
		Handle black promotion square
		
		Revision 1.6  2003/04/25 22:26:23  neerache
		Simplify mouse model, fix startup bug
		
		Revision 1.5  2003/04/25 16:37:00  neerache
		Clean automake build
		
		Revision 1.4  2003/04/24 23:20:35  neeri
		Support pawn promotions
		
		Revision 1.3  2003/04/02 19:01:36  neeri
		Explore strategies to speed up dragging
		
		Revision 1.2  2002/12/04 02:30:50  neeri
		Experiment (unsuccessfully so far) with ways to speed up piece movement
		
		Revision 1.1  2002/08/22 23:47:06  neeri
		Initial Checkin
		
*/

#import "MBCBoardViewMouse.h"
#import "MBCBoardViewDraw.h" // For drawBoardPlane
#import "MBCInteractivePlayer.h"

#import <OpenGL/glu.h>

#import <algorithm>

using std::min;
using std::max;

//
// We're doing a lot of Projects and UnProjects. 
// These classes encapsulate them.
//
class MBCProjector {
public:
	MBCProjector();

	NSPoint Project(MBCPosition pos);
protected:
    GLint		fViewport[4];
    GLdouble	fMVMatrix[16];
	GLdouble	fProjMatrix[16];
};

class MBCUnProjector : private MBCProjector {
public:
	MBCUnProjector(GLdouble winX, GLdouble winY);
	
	MBCPosition UnProject();
	MBCPosition UnProject(GLfloat knownY);
private:
	GLdouble	fWinX;
	GLdouble	fWinY;	
};

MBCProjector::MBCProjector()
{
    glGetIntegerv(GL_VIEWPORT, fViewport);
    glGetDoublev(GL_MODELVIEW_MATRIX, fMVMatrix);
    glGetDoublev(GL_PROJECTION_MATRIX, fProjMatrix);
}

NSPoint MBCProjector::Project(MBCPosition pos)
{
	GLdouble 	w[3];

	gluProject(pos[0], pos[1], pos[2], fMVMatrix, fProjMatrix, fViewport,
			   w+0, w+1, w+2);

	NSPoint pt = {w[0], w[1]};

	return pt;
}

MBCUnProjector::MBCUnProjector(GLdouble winX, GLdouble winY)
	: MBCProjector(), fWinX(winX), fWinY(winY)
{
}

MBCPosition MBCUnProjector::UnProject()
{
	MBCPosition	pos;
	GLfloat		z;
	GLdouble 	wv[3];

    glReadPixels((GLint)fWinX, (GLint)fWinY, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, &z);
    gluUnProject(fWinX, fWinY, z, fMVMatrix, fProjMatrix, fViewport, 
				 wv+0, wv+1, wv+2);

	pos[0] = wv[0];
	pos[1] = wv[1];
	pos[2] = wv[2];

	return pos;
}

MBCPosition MBCUnProjector::UnProject(GLfloat knownY)
{
	MBCPosition	pos;
	GLdouble 	p1[3];
	GLdouble 	p0[3];	

    gluUnProject(fWinX, fWinY, 1.0f, fMVMatrix, fProjMatrix, fViewport, 
				 p1+0, p1+1, p1+2);
    gluUnProject(fWinX, fWinY, 0.0f, fMVMatrix, fProjMatrix, fViewport, 
				 p0+0, p0+1, p0+2);
	GLdouble yint = (knownY-p1[1])/(p0[1]-p1[1]);
	pos[0] = p1[0]+(p0[0]-p1[0])*yint;
	pos[1] = knownY;
	pos[2] = p1[2]+(p0[2]-p1[2])*yint;

	return pos;
}

MBCPosition operator-(const MBCPosition & a, const MBCPosition & b)
{
	MBCPosition	res;
	
	res[0]	= a[0]-b[0];
	res[1]	= a[1]-b[1];
	res[2]	= a[2]-b[2];

	return res;
}

@implementation MBCBoardView ( Mouse )

- (NSRect) approximateBoundsOfSquare:(MBCSquare)square
{
	const float kSquare = 4.5f;

	MBCProjector proj;
	MBCPosition  pos = [self squareToPosition:square];

	pos[0] -= kSquare;
	pos[2] -= kSquare;
	NSPoint p0	= proj.Project(pos);
	
	pos[0] += 2.0f*kSquare;
	NSPoint p1 	= proj.Project(pos);
	
	pos[2] += 2.0f*kSquare;
	NSPoint p2 	= proj.Project(pos);

	pos[0] -= 2.0f*kSquare;
	NSPoint p3 	= proj.Project(pos);

	NSRect r;
	if (p1.x > p0.x) {
		r.origin.x 		= max(p0.x, p3.x);
		r.size.width	= min(p1.x, p2.x)-r.origin.x;
	} else {
		r.origin.x 		= max(p1.x, p2.x);
		r.size.width	= min(p0.x, p3.x)-r.origin.x;
	}
	if (p2.y > p1.y) {
		r.origin.y 		= max(p0.y, p1.y);
		r.size.height	= min(p2.y, p3.y)-r.origin.y;
	} else {
		r.origin.y 		= max(p2.y, p3.y);
		r.size.height	= min(p0.y, p1.y)-r.origin.y;
	}

	return r;
}

- (MBCPosition) mouseToPosition:(NSPoint)mouse
{
	MBCUnProjector	unproj(mouse.x, mouse.y);
	
	return unproj.UnProject();
}

- (MBCPosition) eventToPosition:(NSEvent *)event
{
    NSPoint p = [event locationInWindow];
    NSPoint l = [self convertPoint:p fromView:nil];

	return [self mouseToPosition:l];
}

- (void) mouseMoved:(NSEvent *)event
{
	MBCPosition 	pos 	= [self eventToPosition:event];
	float 			pxa		= fabs(pos[0]);
	float			pza		= fabs(pos[2]);
	NSCursor *		cursor	= fArrowCursor;

	if (pxa > kBoardRadius || pza > kBoardRadius) 
		if (pxa < kBoardRadius+kBorderWidth+.1f 
		 && pza < kBoardRadius+kBorderWidth+.1f)
			cursor	=	fHandCursor;
	[cursor set];
}

- (void) mouseDown:(NSEvent *)event
{
	MBCSquare previouslyPicked = fPickedSquare;

    NSPoint p = [event locationInWindow];
    NSPoint l = [self convertPoint:p fromView:nil];

	//	
	// On mousedown, we determine the point on the board surface that 
	// corresponds to the mouse location by the frontmost Z value, but
	// then pretend that the click happened at board surface level. Weirdly
	// enough, this seems to give the most natural feeling mouse behavior.
	//
	MBCPosition pos = [self mouseToPosition:l];

	MBCSquare selectedStart = fSelectedDest = 
		[self positionToSquareOrRegion:&pos];
    switch (fSelectedDest) {
	case kInvalidSquare:
		return;
	case kWhitePromoSquare:
	case kBlackPromoSquare:
		return;
	case kBorderRegion:
		fInBoardManipulation= true;
		fOrigMouse 			= l;
		fCurMouse 			= l;
		fRawAzimuth 		= fAzimuth;
		fSelectedPiece		= 0;
		[NSCursor hide];
		[NSEvent startPeriodicEventsAfterDelay:0.1f withPeriod:0.1f];
		break;
	default:
		if (!fWantMouse || fInAnimation || pos[1] < 0.1)
			return;
		//
		// Let interactive player decide whether we hit one of their pieces
		//
		[fInteractive startSelection:fSelectedDest];
		if (!fSelectedPiece) // Apparently not...
			return;
		break;
	}
	pos[1]		    	= 0.0f;
	fSelectedStartPos	= pos;
	gettimeofday(&fLastRedraw, NULL);
	fLastSelectedPos	= pos;
	//
	// For better interactivity, we stop the engine while a drag is in progress
	//
	[[fController engine] interruptEngine];
	[self drawNow];
	
	NSDate * whenever = [NSDate distantFuture];
	for (bool goOn = true; goOn; ) {
		event = 
			[NSApp nextEventMatchingMask: 
					   NSPeriodicMask|NSLeftMouseUpMask|NSLeftMouseDraggedMask
				   untilDate:whenever inMode:NSEventTrackingRunLoopMode 
				   dequeue:YES];
        switch ([event type]) {
		case NSPeriodic:
		case NSLeftMouseDragged:
			[self dragAndRedraw:event forceRedraw:NO];
			break;
		case NSLeftMouseUp: {
			[self dragAndRedraw:event forceRedraw:YES];
			[fInteractive endSelection:fSelectedDest animate:NO];
			if (fPickedSquare == previouslyPicked)
				fPickedSquare = kInvalidSquare; // Toggle pick
			goOn = false;
			if (fInBoardManipulation) {
				fInBoardManipulation = false;
				[NSCursor unhide];	
				[NSEvent stopPeriodicEvents];
			}
			break; }
		default:
			/* Ignore any other kind of event. */
			break;
		}		
	}
	fSelectedDest = kInvalidSquare;
}

- (void) mouseUp:(NSEvent *)event
{
	if (!fWantMouse || fInAnimation)
		return;

	MBCPiece promo;
	if (fSelectedDest == kWhitePromoSquare) {
		promo = [fBoard defaultPromotion:YES];
	} else if (fSelectedDest == kBlackPromoSquare) {
		promo = [fBoard defaultPromotion:NO];
	} else if (fPickedSquare != kInvalidSquare) {
		[fInteractive startSelection:fPickedSquare];
		[fInteractive endSelection:fSelectedDest animate:YES];

		return;
	} else
		return;
	
	switch (promo) {
	case QUEEN:
		if (fVariant == kVarSuicide)
			promo = KING;	// King promotion is very popular in suicide
		else
			promo = KNIGHT; // Second most useful
		break;
	case KING: // Suicide only
		promo = KNIGHT;
		break;
	case KNIGHT:
		promo = ROOK;
		break;
	case ROOK:
		promo = BISHOP;
		break;
	case BISHOP:
		promo = QUEEN;
		break;
	}
	[fBoard setDefaultPromotion:promo 
			for:fSelectedDest == kWhitePromoSquare];

	[self setNeedsDisplay:YES];
}

- (void) dragAndRedraw:(NSEvent *)event forceRedraw:(BOOL)force
{
	if ([event type] != NSPeriodic) {
		NSPoint p = [event locationInWindow];
		NSPoint l = [self convertPoint:p fromView:nil];
		fCurMouse = l;
		//
		// On drag, we can use a fairly fast interpolation to determine
		// the 3D coordinate using the y where we touched the piece
		//
		MBCUnProjector	unproj(l.x, l.y);

		fSelectedPos 				= unproj.UnProject(0.0f);
		[self snapToSquare:&fSelectedPos];
	}
	struct timeval	now;
	gettimeofday(&now, NULL);
	MBCPosition		delta		= fSelectedPos-fLastSelectedPos;
	GLfloat			d2      	= delta[0]*delta[0]+delta[2]*delta[2];
	NSTimeInterval	dt			= 
		now.tv_sec - fLastRedraw.tv_sec 
		+ 0.000001 * (now.tv_usec - fLastRedraw.tv_usec);

	const float	kTiltSpeed		=  0.50f;
	const float kSpinSpeed		=  0.50f;
	const float	kThreshold		= 10.0f;
	const float	kAzimuthRound	=  5.0f;

	if (force) {
		[self setNeedsDisplay:YES];	
	} else if (fSelectedDest == kBorderRegion) {
		float dx =  fCurMouse.x-fOrigMouse.x;
		float dy =	fCurMouse.y-fOrigMouse.y;
		if (fabs(dx) > fabs(dy) && fabs(dx) > kThreshold) {
			fRawAzimuth += dx*dt*kSpinSpeed;
			fRawAzimuth = fmod(fRawAzimuth+360.0f, 360.0f);
			float angle	= fmod((fAzimuth = fRawAzimuth), 90.0f);
			if (angle < kAzimuthRound)
				fAzimuth	-= angle;
			else if (angle > 90.0f-kAzimuthRound)
				fAzimuth 	+= 90.0f-angle;
			fNeedPerspective= true;
			fLastRedraw 	= now;
			[self drawNow];
		} else if (fabs(dy) > kThreshold) {
			fElevation -= dy*dt*kTiltSpeed;
			fElevation = 
				max(kMinElevation, min(kMaxElevation, fElevation));
			fNeedPerspective= true;
			fLastRedraw 	= now;
			[self drawNow];
		}
	} else if (d2 > 25.0f || (d2 > 1.0f && dt > 0.02)) {
		fSelectedDest	= [self positionToSquare:&fSelectedPos];
		fLastRedraw 	= now;
		[self drawNow];
	}
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)event
{
	NSString * chr = [event characters];
	if ([chr length] != 1)
		return; // Ignore
	switch (char ch = [chr characterAtIndex:0]) {
	case 'A':
	case 'B':
	case 'C':
	case 'D':
	case 'E':
	case 'F':
	case 'G':
	case 'H':
		ch = tolower(ch);
		// Fall through
	case 'b':
		if (fKeyBuffer == '=')
			goto promotion_piece;
		// Else fall through
	case 'a':
	case 'c':
	case 'd':
	case 'e':
	case 'f':
	case 'g':
	case 'h':
	case '=':
		fKeyBuffer	= ch;
		break;
	case '1':
	case '2':
	case '3':
	case '4':
	case '5':
	case '6':
	case '7':
	case '8':
		if (isalpha(fKeyBuffer)) {
			MBCSquare sq = Square(fKeyBuffer, ch-'0');
			if (fPickedSquare != kInvalidSquare) {
				[fInteractive startSelection:fPickedSquare];
				[fInteractive endSelection:sq animate:YES];
			} else {
				[fInteractive startSelection:sq];
				[self clickPiece];
			}
		} else
			NSBeep();
		fKeyBuffer = 0;
		break;
	case '\177':	// Delete
	case '\r':
		if (fKeyBuffer) {
			fKeyBuffer 	= 0;
		} else if (fPickedSquare != kInvalidSquare) {
			[fInteractive endSelection:fPickedSquare animate:NO];
			fPickedSquare	= kInvalidSquare;
			[self setNeedsDisplay:YES];
		}
		break;
	case 'K':
		if (fVariant != kVarSuicide) {
			NSBeep();
			break;
		}
		// Fall through
	case 'Q':
	case 'N':
	case 'R':
		ch = tolower(ch);
		// Fall through
	case 'k':
		if (fVariant != kVarSuicide) {
			NSBeep();
			break;
		}
		// Fall through
	case 'q':
	case 'n':
	case 'r':		
	promotion_piece:
		if (fKeyBuffer == '=') {
			const char * kPiece = " kqbnr";
			[fBoard setDefaultPromotion:strchr(kPiece, ch)-kPiece for:YES];
			[fBoard setDefaultPromotion:strchr(kPiece, ch)-kPiece for:NO];
			[self setNeedsDisplay:YES];
		} else {
			NSBeep();
		}
	    fKeyBuffer = 0;
	    break;
	}
}

@end

// Local Variables:
// mode:ObjC
// End:
