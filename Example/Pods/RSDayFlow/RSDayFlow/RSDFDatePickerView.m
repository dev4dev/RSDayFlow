//
// RSDFDatePickerView.m
//
// Copyright (c) 2013 Evadne Wu, http://radi.ws/
// Copyright (c) 2013-2016 Ruslan Skorb, http://ruslanskorb.com
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <QuartzCore/QuartzCore.h>
#import "RSDFDatePickerCollectionView.h"
#import "RSDFDatePickerCollectionViewLayout.h"
#import "RSDFDatePickerDate.h"
#import "RSDFDatePickerDayCell.h"
#import "RSDFDatePickerMonthHeader.h"
#import "RSDFDatePickerView.h"
#import "RSDFDatePickerDaysOfWeekView.h"
#import "NSCalendar+RSDFAdditions.h"

static NSString * const RSDFDatePickerViewMonthHeaderIdentifier = @"RSDFDatePickerViewMonthHeaderIdentifier";
static NSString * const RSDFDatePickerViewDayCellIdentifier = @"RSDFDatePickerViewDayCellIdentifier";

@interface RSDFDatePickerView () <UICollectionViewDelegate>

@property (nonatomic, readonly, strong) NSCalendar *calendar;
@property (nonatomic, readonly, strong) RSDFDatePickerDaysOfWeekView *daysOfWeekView;
@property (nonatomic, readonly, strong) RSDFDatePickerCollectionView *collectionView;
@property (nonatomic, readonly, strong) RSDFDatePickerCollectionViewLayout *collectionViewLayout;
@property (nonatomic, readonly, strong) NSDate *today;
@property (nonatomic, readonly, assign) NSUInteger daysInWeek;
@property (nonatomic, readonly, strong) NSDate *selectedDate;
@property (nonatomic, readonly, strong) NSDate *selectedStartDateRange;
@property (nonatomic, readonly, strong) NSDate *selectedEndDateRange;

// From and to date are the currently displayed dates in the calendar.
// These values change in infinite scrolling mode.
@property (nonatomic, readonly, strong) NSDate *fromDate;
@property (nonatomic, readonly, strong) NSDate *toDate;

// Start and end date are date limits displayed in the calendar (no infinite scrolling).
@property (nonatomic, readonly, strong) NSDate *startDate;
@property (nonatomic, readonly, strong) NSDate *endDate;

@end

@implementation RSDFDatePickerView

@synthesize calendar = _calendar;
@synthesize fromDate = _fromDate;
@synthesize toDate = _toDate;
@synthesize daysOfWeekView = _daysOfWeekView;
@synthesize collectionView = _collectionView;
@synthesize collectionViewLayout = _collectionViewLayout;
@synthesize daysInWeek = _daysInWeek;

#pragma mark - Object Lifecycle

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInitializer];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInitializer];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame calendar:(NSCalendar *)calendar startDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    self = [super initWithFrame:frame];
    if (self) {
        _startDate = startDate ? [self dateWithoutTimeComponents:startDate] : nil;
        _endDate = endDate ? [self dateWithoutTimeComponents:endDate] : nil;
        _calendar = calendar;
        [self commonInitializer];
    }
    return self;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    CGPoint beforeLayoutSubviewsContentOffset = self.collectionView.contentOffset;
    
    [super layoutSubviews];
    
    self.daysOfWeekView.frame = [self daysOfWeekViewFrame];
    if (!self.daysOfWeekView.superview) {
        [self addSubview:self.daysOfWeekView];
    }
    
    self.collectionView.frame = [self collectionViewFrame];
    if (!self.collectionView.superview) {
        [self addSubview:self.collectionView];
    } else {
        [self.collectionViewLayout invalidateLayout];
        [self.collectionViewLayout prepareLayout];
        self.collectionView.contentOffset = beforeLayoutSubviewsContentOffset;
    }
}

#pragma mark - Properties

- (NSCalendar *)calendar
{
    if (!_calendar) {
        _calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        _calendar.locale = [NSLocale currentLocale];
    }
    return _calendar;
}

- (RSDFDatePickerCollectionView *)collectionView
{
    if (!_collectionView) {
        _collectionView = [[[self collectionViewClass] alloc] initWithFrame:[self collectionViewFrame] collectionViewLayout:self.collectionViewLayout];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        [_collectionView registerClass:[self monthHeaderClass] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:RSDFDatePickerViewMonthHeaderIdentifier];
        [_collectionView registerClass:[self dayCellClass] forCellWithReuseIdentifier:RSDFDatePickerViewDayCellIdentifier];
        [_collectionView reloadData];
        [_collectionView layoutIfNeeded];
//        [self scrollToToday:NO];
    }
    return _collectionView;
}

- (Class)collectionViewClass
{
    return [RSDFDatePickerCollectionView class];
}

- (CGRect)collectionViewFrame
{
    CGFloat daysOfWeekViewHeight = CGRectGetHeight([self daysOfWeekViewFrame]);
    
    CGRect collectionViewFrame = self.bounds;
    collectionViewFrame.origin.y += daysOfWeekViewHeight;
    collectionViewFrame.size.height -= daysOfWeekViewHeight;
    return collectionViewFrame;
}

- (RSDFDatePickerCollectionViewLayout *)collectionViewLayout
{
    if (!_collectionViewLayout) {
        NSLocaleLanguageDirection characterDirection = [NSLocale characterDirectionForLanguage:self.calendar.locale.localeIdentifier];
        RSDFDatePickerCollectionViewLayoutDirection layoutDirection;
        if (characterDirection == NSLocaleLanguageDirectionRightToLeft) {
            layoutDirection = RSDFDatePickerCollectionViewLayoutDirectionRightToLeft;
        } else {
            layoutDirection = RSDFDatePickerCollectionViewLayoutDirectionLeftToRight;
        }
        _collectionViewLayout = [[[self collectionViewLayoutClass] alloc] initWithDirection:layoutDirection];
    }
    return _collectionViewLayout;
}

- (Class)collectionViewLayoutClass
{
    return [RSDFDatePickerCollectionViewLayout class];
}

- (Class)dayCellClass
{
    return [RSDFDatePickerDayCell class];
}

- (NSUInteger)daysInWeek
{
    if (_daysInWeek == 0) {
        _daysInWeek = self.calendar.rsdf_daysInWeek;
    }
    return _daysInWeek;
}

- (void)setSelectionMode:(RSDFSelectionMode)selectionMode
{
	_selectionMode = selectionMode;

	switch (selectionMode) {
		case RSDFSelectionModeSingle: {
			[self clearRangeSelection];
			break;
		}
		case RSDFSelectionModeRange: {
			[self selectDate:nil];
			break;
		}
	}
	self.collectionView.allowsMultipleSelection = selectionMode == RSDFSelectionModeRange;
}

- (RSDFDatePickerDaysOfWeekView *)daysOfWeekView
{
    if (!_daysOfWeekView) {
        _daysOfWeekView = [[[self daysOfWeekViewClass] alloc] initWithFrame:[self daysOfWeekViewFrame] calendar:self.calendar];
        [_daysOfWeekView layoutIfNeeded];
    }
    return _daysOfWeekView;
}

- (Class)daysOfWeekViewClass
{
    return [RSDFDatePickerDaysOfWeekView class];
}

- (CGRect)daysOfWeekViewFrame
{
    CGRect daysOfWeekViewFrame = self.bounds;
    daysOfWeekViewFrame.size.height = [self daysOfWeekViewHeight];
    
    return daysOfWeekViewFrame;
}

- (CGFloat)daysOfWeekViewHeight
{
    CGFloat daysOfWeekViewHeight = 0.0f;
    
    BOOL isPhone = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;
    BOOL isPortraitInterfaceOrientation = UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]);
    
    if (isPhone) {
        if (isPortraitInterfaceOrientation) {
            daysOfWeekViewHeight = 22.0f;
        } else {
            daysOfWeekViewHeight = 26.0f;
        }
    } else {
        daysOfWeekViewHeight = 36.0f;
    }
    
    return daysOfWeekViewHeight;
}

- (Class)monthHeaderClass
{
    return [RSDFDatePickerMonthHeader class];
}

#pragma mark - Handling Notifications

- (void)significantTimeChange:(NSNotification *)notification
{
    NSDateComponents *todayYearMonthDayComponents = [self.calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:[NSDate date]];
    _today = [self.calendar dateFromComponents:todayYearMonthDayComponents];
    
    [self.collectionView reloadData];
    [self restoreSelection];
}

#pragma mark - Public

- (void)reloadData
{
    [self.collectionView reloadData];
}

- (void)scrollToDate:(NSDate *)date animated:(BOOL)animated
{
    if (self.startDate && [date compare:self.startDate] == NSOrderedAscending) {
        return;
    }
    
    if (self.endDate && [date compare:self.endDate] == NSOrderedDescending) {
        return;
    }
    
    RSDFDatePickerCollectionView *cv = self.collectionView;
    RSDFDatePickerCollectionViewLayout *cvLayout = (RSDFDatePickerCollectionViewLayout *)self.collectionView.collectionViewLayout;
    
    NSDateComponents *dateYearMonthComponents = [self.calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth) fromDate:date];
    NSDate *month = [self.calendar dateFromComponents:dateYearMonthComponents];
    
    // If startDate exists don't try to update toDate because it was done on init, and date limit should remain.
    if (!self.startDate) {
        _fromDate = [self dateWithFirstDayOfMonth:[self.calendar dateByAddingComponents:((^{
            NSDateComponents *components = [NSDateComponents new];
            components.month = -6;
            return components;
        })()) toDate:month options:0]];
    }
    
    // If endDate exists don't try to update toDate because it was done on init, and date limit should remain.
    if (!self.endDate) {
        _toDate = [self dateWithFirstDayOfMonth:[self.calendar dateByAddingComponents:((^{
            NSDateComponents *components = [NSDateComponents new];
            components.month = 6;
            return components;
        })()) toDate:month options:0]];
    }
    
    [cv reloadData];
    [cvLayout invalidateLayout];
    [cvLayout prepareLayout];
    
    [self restoreSelection];
    
    NSIndexPath *dateItemIndexPath = [self indexPathForDate:date];
    NSInteger monthSection = [self sectionForDate:date];
    
    CGRect dateItemRect = [self frameForItemAtIndexPath:dateItemIndexPath];
    CGRect monthSectionHeaderRect = [self frameForHeaderForSection:monthSection];
    
    CGFloat delta = CGRectGetMaxY(dateItemRect) - CGRectGetMinY(monthSectionHeaderRect);
    CGFloat actualViewHeight = CGRectGetHeight(cv.frame) - cv.contentInset.top - cv.contentInset.bottom;
    
    if (delta <= actualViewHeight) {
        [self scrollToTopOfSection:monthSection animated:animated];
    } else {
        [cv scrollToItemAtIndexPath:dateItemIndexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:animated];
    }
}

- (void)scrollToToday:(BOOL)animated
{
    [self scrollToDate:self.today animated:animated];
}

- (void)selectDate:(NSDate *)date
{
    if (![self.selectedDate isEqual:date]) {
        if (self.selectedDate &&
            [self.selectedDate compare:self.fromDate] != NSOrderedAscending &&
            [self.selectedDate compare:self.toDate] == NSOrderedAscending) {
            NSIndexPath *previousSelectedCellIndexPath = [self indexPathForDate:self.selectedDate];
            [self.collectionView deselectItemAtIndexPath:previousSelectedCellIndexPath animated:NO];
            UICollectionViewCell *previousSelectedCell = [self.collectionView cellForItemAtIndexPath:previousSelectedCellIndexPath];
            if (previousSelectedCell) {
                [previousSelectedCell setNeedsDisplay];
            }
        }
        
        _selectedDate = date;
        
        if (self.selectedDate &&
            [self.selectedDate compare:self.fromDate] != NSOrderedAscending &&
            [self.selectedDate compare:self.toDate] == NSOrderedAscending) {
            NSIndexPath *indexPathForSelectedDate = [self indexPathForDate:self.selectedDate];
            [self.collectionView selectItemAtIndexPath:indexPathForSelectedDate animated:NO scrollPosition:UICollectionViewScrollPositionNone];
            UICollectionViewCell *selectedCell = [self.collectionView cellForItemAtIndexPath:indexPathForSelectedDate];
            if (selectedCell) {
                [selectedCell setNeedsDisplay];
            }
        }
    }
}

- (void)selectDateRange:(NSDate * __nullable)firstDate lastDate:(NSDate * __nullable)lastDate
{
	[self selectDateInDateRange:firstDate];
	[self selectDateInDateRange:lastDate];
}

- (void)clearSelection
{
	[self selectDate:nil];
	[self clearRangeSelection];
	_selectedStartDateRange = nil;
	_selectedEndDateRange = nil;
}

- (void)commonInitializer
{
    NSDateComponents *nowYearMonthComponents = [self.calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth) fromDate:[NSDate date]];
    NSDate *now = [self.calendar dateFromComponents:nowYearMonthComponents];
    
    if (self.startDate) {
        _fromDate = [self dateWithFirstDayOfMonth:self.startDate];
    } else {
        _fromDate = [self dateWithFirstDayOfMonth:[self.calendar dateByAddingComponents:((^{
            NSDateComponents *components = [NSDateComponents new];
            components.month = -6;
            return components;
        })()) toDate:now options:0]];
    }
    
    if (self.endDate) {
        _toDate = [self dateWithFirstDayOfNextMonth:self.endDate];
    } else {
        _toDate = [self dateWithFirstDayOfMonth:[self.calendar dateByAddingComponents:((^{
            NSDateComponents *components = [NSDateComponents new];
            components.month = 6;
            return components;
        })()) toDate:now options:0]];
    }


    NSDateComponents *todayYearMonthDayComponents = [self.calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:[NSDate date]];
    _today = [self.calendar dateFromComponents:todayYearMonthDayComponents];

	self.selectionMode = RSDFSelectionModeSingle;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(significantTimeChange:)
                                                 name:UIApplicationSignificantTimeChangeNotification
                                               object:nil];
}

- (NSDate *)dateWithFirstDayOfNextMonth:(NSDate *)date
{
    NSDateComponents *components = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    
    components.month = components.month + 1;
    components.day = 1;
    return [self.calendar dateFromComponents:components];
}

- (NSDate *)dateForCellAtIndexPath:(NSIndexPath *)indexPath
{
    NSDate *firstDayInMonth = [self dateForFirstDayInSection:indexPath.section];
    NSUInteger weekday = [self reorderedWeekday:[self.calendar components:NSCalendarUnitWeekday fromDate:firstDayInMonth].weekday];
    
    NSDate *cellDate = [self.calendar dateByAddingComponents:((^{
        NSDateComponents *dateComponents = [NSDateComponents new];
        dateComponents.day = indexPath.item - weekday;
        return dateComponents;
    })()) toDate:firstDayInMonth options:0];
    
    return cellDate;
}

- (NSDate *)dateForFirstDayInSection:(NSInteger)section
{
    return [self.calendar dateByAddingComponents:((^{
        NSDateComponents *dateComponents = [NSDateComponents new];
        dateComponents.month = section;
        return dateComponents;
    })()) toDate:self.fromDate options:0];
}

- (NSDate *)dateWithFirstDayOfMonth:(NSDate *)date
{
    NSDateComponents *dateComponents = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    dateComponents.day = 1;
    return [self.calendar dateFromComponents:dateComponents];
}

- (NSDate *)dateWithoutTimeComponents:(NSDate *)date
{
    NSDateComponents *dateComponents = [self.calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    return [self.calendar dateFromComponents:dateComponents];
}

- (CGRect)frameForHeaderForSection:(NSInteger)section
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:section];
    UICollectionViewLayoutAttributes *attributes = [self.collectionView layoutAttributesForSupplementaryElementOfKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
    
    return attributes.frame;
}

- (CGRect)frameForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attributes = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
    
    return attributes.frame;
}

- (NSIndexPath *)indexPathForDate:(NSDate *)date
{
    NSInteger monthSection = [self sectionForDate:date];
    NSDate *firstDayInMonth = [self dateForFirstDayInSection:monthSection];
    NSUInteger weekday = [self reorderedWeekday:[self.calendar components:NSCalendarUnitWeekday fromDate:firstDayInMonth].weekday];
    NSInteger dateItem = [self.calendar components:NSCalendarUnitDay fromDate:firstDayInMonth toDate:date options:0].day + weekday;
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:dateItem inSection:monthSection];
    
    return indexPath;
}

- (NSUInteger)numberOfWeeksForMonthOfDate:(NSDate *)date
{
    NSDate *firstDayInMonth = [self.calendar dateFromComponents:[self.calendar components:NSCalendarUnitYear|NSCalendarUnitMonth fromDate:date]];
    
    NSDate *lastDayInMonth = [self.calendar dateByAddingComponents:((^{
        NSDateComponents *dateComponents = [NSDateComponents new];
        dateComponents.month = 1;
        dateComponents.day = -1;
        return dateComponents;
    })()) toDate:firstDayInMonth options:0];
    
    NSDate *fromFirstWeekday = [self.calendar dateFromComponents:((^{
        NSDateComponents *dateComponents = [self.calendar components:NSCalendarUnitWeekOfYear|NSCalendarUnitYearForWeekOfYear fromDate:firstDayInMonth];
        dateComponents.weekday = self.calendar.firstWeekday;
        return dateComponents;
    })())];
    
    NSDate *toFirstWeekday = [self.calendar dateFromComponents:((^{
        NSDateComponents *dateComponents = [self.calendar components:NSCalendarUnitWeekOfYear|NSCalendarUnitYearForWeekOfYear fromDate:lastDayInMonth];
        dateComponents.weekday = self.calendar.firstWeekday;
        return dateComponents;
    })())];
    
    return 1 + [self.calendar components:NSCalendarUnitWeekOfYear fromDate:fromFirstWeekday toDate:toFirstWeekday options:0].weekOfYear;
}

- (RSDFDatePickerDate)pickerDateFromDate:(NSDate *)date
{
    NSDateComponents *components = [self.calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
    return (RSDFDatePickerDate) {
        components.year,
        components.month,
        components.day
    };
}

- (NSUInteger)reorderedWeekday:(NSUInteger)weekday
{
    NSInteger ordered = weekday - self.calendar.firstWeekday;
    if (ordered < 0) {
        ordered = self.daysInWeek + ordered;
    }
    
    return ordered;
}

- (void)restoreSelection
{
	if (self.selectionMode == RSDFSelectionModeSingle) {
		if (self.selectedDate &&
			[self.selectedDate compare:self.fromDate] != NSOrderedAscending &&
			[self.selectedDate compare:self.toDate] == NSOrderedAscending) {
			NSIndexPath *indexPathForSelectedDate = [self indexPathForDate:self.selectedDate];
			[self.collectionView selectItemAtIndexPath:indexPathForSelectedDate animated:NO scrollPosition:UICollectionViewScrollPositionNone];
			UICollectionViewCell *selectedCell = [self.collectionView cellForItemAtIndexPath:indexPathForSelectedDate];
			if (selectedCell) {
				[selectedCell setNeedsDisplay];
			}
		}
	} else {
		// If both exist select all items in range
		if (self.selectedStartDateRange && self.selectedEndDateRange) {
			NSIndexPath *firstIndexPath = [self indexPathForDate:self.selectedStartDateRange];
			NSIndexPath *lastIndexPath = [self indexPathForDate:self.selectedEndDateRange];

			if (firstIndexPath && lastIndexPath) {
				__weak typeof(self) weakSelf = self;

				[self enumerateBetweenFirstIndexPath:firstIndexPath secondIndexPath:lastIndexPath withBlock:^(NSIndexPath *indexPath) {
					[weakSelf.collectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionNone];
					[[weakSelf.collectionView cellForItemAtIndexPath:indexPath] setNeedsDisplay];
				}];
			}
		} else { // If only one exists only select that one
			if (self.selectedStartDateRange || self.selectedEndDateRange) {
				NSIndexPath *indexPath =  [self indexPathForDate:self.selectedStartDateRange ? self.selectedStartDateRange : self.selectedEndDateRange];

				[self.collectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionNone];
				[[self.collectionView cellForItemAtIndexPath:indexPath] setNeedsDisplay];
			}
		}
	}
}

- (void)scrollToTopOfSection:(NSInteger)section animated:(BOOL)animated
{
    CGRect headerRect = [self frameForHeaderForSection:section];
    CGPoint topOfHeader = CGPointMake(0, headerRect.origin.y - _collectionView.contentInset.top);
    [_collectionView setContentOffset:topOfHeader animated:animated];
}

- (NSInteger)sectionForDate:(NSDate *)date;
{
    return [self.calendar components:NSCalendarUnitMonth fromDate:[self dateForFirstDayInSection:0] toDate:date options:0].month;
}

- (void)shiftDatesByComponents:(NSDateComponents *)components
{
    RSDFDatePickerCollectionView *cv = self.collectionView;
    RSDFDatePickerCollectionViewLayout *cvLayout = (RSDFDatePickerCollectionViewLayout *)self.collectionView.collectionViewLayout;
    
    NSArray *visibleCells = [cv visibleCells];
    if (![visibleCells count])
        return;
    
    NSIndexPath *fromIndexPath = [cv indexPathForCell:((UICollectionViewCell *)visibleCells[0]) ];
    NSInteger fromSection = fromIndexPath.section;
    NSDate *fromSectionOfDate = [self dateForFirstDayInSection:fromSection];
    UICollectionViewLayoutAttributes *fromAttrs = [cvLayout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:fromSection]];
    CGPoint fromSectionOrigin = [self convertPoint:fromAttrs.frame.origin fromView:cv];
    
    if (!self.startDate) {
        _fromDate = [self dateWithFirstDayOfMonth:[self.calendar dateByAddingComponents:components toDate:self.fromDate options:0]];
    }
    
    if (!self.endDate) {
        _toDate = [self dateWithFirstDayOfMonth:[self.calendar dateByAddingComponents:components toDate:self.toDate options:0]];
    }
    
#if 0
    
    //	This solution trips up the collection view a bit
    //	because our reload is reactionary, and happens before a relayout
    //	since we must do it to avoid flickering and to heckle the CA transaction (?)
    //	that could be a small red flag too.
    
    [cv performBatchUpdates:^{
        
        if (components.month < 0) {
            
            [cv deleteSections:[NSIndexSet indexSetWithIndexesInRange:(NSRange){
                cv.numberOfSections - abs(components.month),
                abs(components.month)
            }]];
            
            [cv insertSections:[NSIndexSet indexSetWithIndexesInRange:(NSRange){
                0,
                abs(components.month)
            }]];
            
        } else {
            
            [cv insertSections:[NSIndexSet indexSetWithIndexesInRange:(NSRange){
                cv.numberOfSections,
                abs(components.month)
            }]];
            
            [cv deleteSections:[NSIndexSet indexSetWithIndexesInRange:(NSRange){
                0,
                abs(components.month)
            }]];
            
        }
        
    } completion:^(BOOL finished) {
        
        NSLog(@"%s %x", __PRETTY_FUNCTION__, finished);
        
    }];
    
    for (UIView *view in cv.subviews)
        [view.layer removeAllAnimations];
    
#else
    
    [cv reloadData];
    [cvLayout invalidateLayout];
    [cvLayout prepareLayout];
    
    [self restoreSelection];
    
#endif
    
    NSInteger toSection = [self sectionForDate:fromSectionOfDate];
    UICollectionViewLayoutAttributes *toAttrs = [cvLayout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:toSection]];
    CGPoint toSectionOrigin = [self convertPoint:toAttrs.frame.origin fromView:cv];
    
    [cv setContentOffset:(CGPoint) {
        cv.contentOffset.x,
        cv.contentOffset.y + (toSectionOrigin.y - fromSectionOrigin.y)
    }];
}

#pragma mark - Private

- (void)handleSelectAndDeselect:(NSIndexPath *)indexPath
{
	RSDFDatePickerDayCell *cell = ((RSDFDatePickerDayCell *)[self.collectionView cellForItemAtIndexPath:indexPath]);
	NSDate *date = cell ? [self dateFromPickerDate:cell.date] : nil;

	if (self.selectionMode == RSDFSelectionModeSingle) {
		[self selectDate:date];

		if ([self.delegate respondsToSelector:@selector(datePickerView:didSelectDate:)]) {
			[self.delegate datePickerView:self didSelectDate:date];
		}
	} else {
		[self selectDateInDateRange:date];

		if ([self.delegate respondsToSelector:@selector(datePickerView:didSelectStartDate:endDate:)]) {
			[self.delegate datePickerView:self didSelectStartDate:self.selectedStartDateRange endDate:self.selectedEndDateRange];
		}
	}
}

- (void)clearRangeSelection
{
	if (self.selectedStartDateRange && self.selectedEndDateRange) {

		NSIndexPath *firstIndexPath = [self indexPathForDate:self.selectedStartDateRange];
		NSIndexPath *lastIndexPath = [self indexPathForDate:self.selectedEndDateRange];

		[self enumerateBetweenFirstIndexPath:firstIndexPath secondIndexPath:lastIndexPath withBlock:^(NSIndexPath *indexPath) {
			[self.collectionView deselectItemAtIndexPath:indexPath animated:NO];
			[[self.collectionView cellForItemAtIndexPath:indexPath] setNeedsDisplay];
		}];

		_selectedStartDateRange = nil;
		_selectedEndDateRange = nil;
	}
}

- (void)selectDateInDateRange:(NSDate *)date
{
	__weak typeof(self) weakSelf = self;

	// Range already completed, user is trying to cancel and start a new range (reset)
	[self clearRangeSelection];

	if (!date) {
		return;
	}
	if (self.selectedStartDateRange == nil) {
		_selectedStartDateRange = date;

		NSIndexPath *indexPathForSelectedDate = [self indexPathForDate:date];
		[self.collectionView selectItemAtIndexPath:indexPathForSelectedDate animated:YES scrollPosition:UICollectionViewScrollPositionNone];
	}
	else {
		// Rearrange first an second date so that they are in ascending order
		if ([date compare:self.selectedStartDateRange] == NSOrderedAscending) {
			_selectedEndDateRange = self.selectedStartDateRange;
			_selectedStartDateRange = date;
		}
		else {
			_selectedEndDateRange = date;
		}

		NSIndexPath *firstIndexPath = [self indexPathForDate:self.selectedStartDateRange];
		NSIndexPath *lastIndexPath = [self indexPathForDate:self.selectedEndDateRange];

		[self enumerateBetweenFirstIndexPath:firstIndexPath secondIndexPath:lastIndexPath withBlock:^(NSIndexPath *indexPath) {
			[weakSelf.collectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionNone];
			[[weakSelf.collectionView cellForItemAtIndexPath:indexPath] setNeedsDisplay];
		}];
	}
}

- (void)enumerateBetweenFirstIndexPath:(NSIndexPath *)firstIndexPath secondIndexPath:(NSIndexPath *)lastIndexPath withBlock:(void (^)(NSIndexPath *))block
{
	for (NSUInteger section = firstIndexPath.section ; section <= lastIndexPath.section ; section++) {

		NSUInteger rowToStart = section == firstIndexPath.section ? firstIndexPath.row : 0;
		NSUInteger rowToEnd = section == lastIndexPath.section ? lastIndexPath.row : [self collectionView:self.collectionView numberOfItemsInSection:section];

		for (NSUInteger row = rowToStart ; row <= rowToEnd ; row++) {

			NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
			block(indexPath);
		}
	}
}

- (NSDate *)dateFromPickerDate:(RSDFDatePickerDate)dateStruct
{
	return [self.calendar dateFromComponents:[self dateComponentsFromPickerDate:dateStruct]];
}

- (NSDateComponents *)dateComponentsFromPickerDate:(RSDFDatePickerDate)dateStruct
{
	NSDateComponents *components = [NSDateComponents new];
	components.year = dateStruct.year;
	components.month = dateStruct.month;
	components.day = dateStruct.day;
	return components;
}

#pragma mark - <UICollectionViewDataSource>

- (RSDFDatePickerDayCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    RSDFDatePickerDayCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:RSDFDatePickerViewDayCellIdentifier forIndexPath:indexPath];

    NSDate *firstDayInMonth = [self dateForFirstDayInSection:indexPath.section];
    NSUInteger firstDayInMonthWeekday = [self reorderedWeekday:[self.calendar components:NSCalendarUnitWeekday fromDate:firstDayInMonth].weekday];
    
    NSDate *cellDate = [self.calendar dateByAddingComponents:((^{
        NSDateComponents *dateComponents = [NSDateComponents new];
        dateComponents.day = indexPath.item - firstDayInMonthWeekday;
        return dateComponents;
    })()) toDate:firstDayInMonth options:0];
    RSDFDatePickerDate cellPickerDate = [self pickerDateFromDate:cellDate];
    
    cell.date = cellPickerDate;
    cell.dateLabel.text = [NSString stringWithFormat:@"%tu", cellPickerDate.day];
    
    RSDFDatePickerDate firstDayPickerDate = [self pickerDateFromDate:firstDayInMonth];
    cell.notThisMonth = !((firstDayPickerDate.year == cellPickerDate.year) && (firstDayPickerDate.month == cellPickerDate.month));
    
    cell.dateLabel.isAccessibilityElement = NO;
    cell.isAccessibilityElement = !cell.notThisMonth;
    
    if (!cell.isNotThisMonth) {
        NSUInteger cellDateWeekday = [self.calendar components:NSCalendarUnitWeekday fromDate:cellDate].weekday;
        cell.dayOff = (cellDateWeekday == 7) || (cellDateWeekday == 1);
        
        if ([self.dataSource respondsToSelector:@selector(datePickerView:shouldMarkDate:)]) {
            cell.marked = [self.dataSource datePickerView:self shouldMarkDate:cellDate];
            
            if (cell.marked) {
                if ([self.dataSource respondsToSelector:@selector(datePickerView:markImageForDate:)]) {
                    cell.markImage = [self.dataSource datePickerView:self markImageForDate:cellDate];
                } else if ([self.dataSource respondsToSelector:@selector(datePickerView:markImageColorForDate:)]) {
                    cell.markImageColor = [self.dataSource datePickerView:self markImageColorForDate:cellDate];
                }
            }
        }
        
        NSComparisonResult result = [_today compare:cellDate];
		cell.today = (result == NSOrderedSame);
		cell.pastDate = (result == NSOrderedDescending);

        if ((self.startDate && [cellDate compare:self.startDate] == NSOrderedAscending) ||
            (self.endDate && [cellDate compare:self.endDate] == NSOrderedDescending)) {
            cell.outOfRange = YES;
        } else {
            cell.outOfRange = NO;
        }
        
        cell.accessibilityLabel = [NSDateFormatter localizedStringFromDate:cellDate dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
    }
    
    [cell setNeedsDisplay];
    
    return cell;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.daysInWeek * [self numberOfWeeksForMonthOfDate:[self dateForFirstDayInSection:section]];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        
        RSDFDatePickerMonthHeader *monthHeader = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:RSDFDatePickerViewMonthHeaderIdentifier forIndexPath:indexPath];
        
        NSString *dateFormatterName = [NSString stringWithFormat:@"calendarMonthHeader_%@_%@", [self.calendar calendarIdentifier], [[self.calendar locale] localeIdentifier]];
        NSDateFormatter *dateFormatter = [self.calendar df_dateFormatterNamed:dateFormatterName withConstructor:^{
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setCalendar:self.calendar];
            [dateFormatter setLocale:[self.calendar locale]];
            return dateFormatter;
        }];
        
        NSDate *formattedDate = [self dateForFirstDayInSection:indexPath.section];
        RSDFDatePickerDate date = [self pickerDateFromDate:formattedDate];
        
        monthHeader.date = date;
        
        NSString *monthString = [dateFormatter shortStandaloneMonthSymbols][date.month - 1];
        monthHeader.dateLabel.text = [[NSString stringWithFormat:@"%@ %tu", monthString, date.year] uppercaseString];
        
        RSDFDatePickerDate today = [self pickerDateFromDate:_today];
        if ( (today.month == date.month) && (today.year == date.year) ) {
            monthHeader.currentMonth = YES;
        } else {
            monthHeader.currentMonth = NO;
        }
        
        return monthHeader;
        
    }
    
    return nil;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [self.calendar components:NSCalendarUnitMonth fromDate:self.fromDate toDate:self.toDate options:0].month;
}

#pragma mark - <UICollectionViewDelegate>

//	We are cheating by piggybacking on view state to avoid recalculation
//	in -collectionView:shouldHighlightItemAtIndexPath:
//	and -collectionView:shouldSelectItemAtIndexPath:.

//	A naive refactoring process might introduce duplicate state which is bad too.

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [cell setNeedsDisplay];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	[self handleSelectAndDeselect:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
	if (self.selectionMode == RSDFSelectionModeRange) {
		[self handleSelectAndDeselect:indexPath];
	}
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [cell setNeedsDisplay];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    RSDFDatePickerDayCell *cell = (RSDFDatePickerDayCell *)[collectionView cellForItemAtIndexPath:indexPath];
    
    if (cell.isNotThisMonth || cell.isOutOfRange) {
        return NO;
    }
    
    if ([self.delegate respondsToSelector:@selector(datePickerView:shouldHighlightDate:)]) {
        NSDate *date = [self dateForCellAtIndexPath:indexPath];
        return [self.delegate datePickerView:self shouldHighlightDate:date];
    }
    
    return YES;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    RSDFDatePickerDayCell *cell = ((RSDFDatePickerDayCell *)[self.collectionView cellForItemAtIndexPath:indexPath]);
    
    if (cell.isNotThisMonth || cell.isOutOfRange) {
        return NO;
    }
    
    if ([self.delegate respondsToSelector:@selector(datePickerView:shouldSelectDate:)]) {
        NSDate *date = [self dateForCellAtIndexPath:indexPath];
        return [self.delegate datePickerView:self shouldSelectDate:date];
    }
    
    return YES;
}

#pragma mark - <UICollectionViewDelegateFlowLayout>

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(RSDFDatePickerCollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    return [collectionViewLayout selfHeaderReferenceSize];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(RSDFDatePickerCollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionViewLayout selfItemSize];
}

@end
