//
//  ViewController.m
//  FindMeAStarbucks
//
//  Created by Anand Kumar 5 on 3/7/15.
//  Copyright (c) 2015 OutOnAWeekend. All rights reserved.
//

#import "ViewController.h"
#import "StarbucksLocation.h"
#import "Reachability.h"
@import MapKit;

@interface ViewController () <MKMapViewDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic) MKUserLocation *userLocation;
@property (nonatomic) MKPointAnnotation *userLocationAnnotation;
@property (nonatomic) MKLocalSearch *starbucksSearch;
@property (nonatomic) MKLocalSearchRequest *starbucksSearchRequest;
@property (nonatomic) NSMutableArray *starbucksLocations;

@property (strong, nonatomic) IBOutlet UIButton *previousButton;
@property (strong, nonatomic) IBOutlet UIButton *indexButton;
@property (strong, nonatomic) IBOutlet UIButton *nextButton;
@property (nonatomic) UIAlertView *alertView;

@property BOOL userLocationUpdated;
@property BOOL changingStarbucksLocation;
@property int currentStarbucksIndex;

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) Reachability* reachability;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Configure the internet reachability check
    __unsafe_unretained typeof(self) weakSelf = self;
    self.reachability = [Reachability reachabilityForInternetConnection];
    self.reachability.reachableBlock = ^(Reachability* reach) {
        [weakSelf.alertView dismissWithClickedButtonIndex:-1 animated:YES];
    };
    self.reachability.unreachableBlock = ^(Reachability* reach) {
        weakSelf.alertView = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"ENABLE CONNECTIVITY", nil) delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [weakSelf.alertView show];
    };
    dispatch_async(dispatch_get_global_queue(0,0), ^{
        [self.reachability startNotifier];
    });
    
    
    self.locationManager = [CLLocationManager new];
    self.locationManager.delegate = self;
    
    //Request for location access authorization (needed in iOS8)
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    
    /*Check if the device - 
     1. Is connected to internet
     2. Has the location service turned on
     3. Has authorized the app to access location service
     Show appropriate message to the user in each case
     */
    if ([self.reachability currentReachabilityStatus] == NotReachable) {
        self.alertView = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"ENABLE CONNECTIVITY", nil) delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [self.alertView show];
    }
    else {
        if (![CLLocationManager locationServicesEnabled]) {
            self.alertView = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"ENABLE DEVICE LOCATION SERVICES", nil) delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [self.alertView show];
        }
        else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
            self.alertView = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"ENABLE APP LOCATION SERVICES", nil) delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [self.alertView show];
        }
    }
    
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    self.userLocationUpdated = NO;
    self.changingStarbucksLocation = NO;
    self.currentStarbucksIndex = -1;
    
    self.previousButton.hidden = YES;
    self.indexButton.hidden = YES;
    self.nextButton.hidden = YES;
    
    [self.view addSubview:self.previousButton];
    [self.view addSubview:self.indexButton];
    [self.view addSubview:self.nextButton];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Highlight the annotation for previous Starbucks
- (IBAction)previousButtonPressed:(id)sender {
    self.currentStarbucksIndex = ((self.currentStarbucksIndex - 1) >= 0)?(self.currentStarbucksIndex - 1):9;
    [self showStarbucksLocation:self.currentStarbucksIndex];
}

// Reposition the map to show the current Starbucks. Useful if the user has moved the map to a different area or has zoomed in so much that the user's current location is not visible anymore.
- (IBAction)indexButtonPressed:(id)sender {
    [self showStarbucksLocation:self.currentStarbucksIndex];
}

// Highlight the annotation for next Starbucks
- (IBAction)nextButtonPressed:(id)sender {
    self.currentStarbucksIndex = ((self.currentStarbucksIndex + 1) < self.starbucksLocations.count)?(self.currentStarbucksIndex + 1):0;
    [self showStarbucksLocation:self.currentStarbucksIndex];
}

// Once the user's location has been ascertained, start a search for nearby Starbucks (preferably within 9000 meters, i.e. ~5.5 miles
- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    if (!self.userLocationUpdated) {
        self.userLocation = userLocation;
        self.userLocationAnnotation = [MKPointAnnotation new];
        self.userLocationAnnotation.coordinate = userLocation.coordinate;
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(userLocation.coordinate, 9000, 9000);
        [self.mapView setRegion:[self.mapView regionThatFits:region] animated:YES];
        self.userLocationUpdated = YES;
        
        [self startStarbucksSearch];
    }
}

// When the map repositions itself to show the current Starbucks and user's location, update the UI elements, i.e. annotation and label accordingly
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if (self.changingStarbucksLocation == YES) {
        [self.mapView deselectAnnotation:self.userLocationAnnotation animated:NO];
        if (self.previousButton.hidden == YES) {
            self.previousButton.hidden = NO;
            self.indexButton.hidden = NO;
            self.nextButton.hidden = NO;
        }
        
        self.changingStarbucksLocation = NO;
        StarbucksLocation *location = [self.starbucksLocations objectAtIndex:self.currentStarbucksIndex];
        [self.mapView selectAnnotation:location.annotation animated:YES];
        
        NSString *indexFormat = NSLocalizedString(@"LOCATION INDEX", nil);
        [self.indexButton setTitle:[NSString stringWithFormat:indexFormat,@(self.currentStarbucksIndex + 1),@(self.starbucksLocations.count)] forState:UIControlStateNormal];

    }
}

- (void)startStarbucksSearch {
    
    if (!self.starbucksSearch) {
        self.starbucksSearchRequest = [MKLocalSearchRequest new];
        self.starbucksSearchRequest.naturalLanguageQuery = @"Starbucks";
        self.starbucksSearchRequest.region = self.mapView.region;
    }
    
    self.starbucksSearch = [[MKLocalSearch alloc] initWithRequest:self.starbucksSearchRequest];
    
    [self.starbucksSearch startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error){
        
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        
        if (error != nil || [response.mapItems count] == 0) {
            [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"STARBUCKS NOT FOUND", nil) delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
        }
        
        self.starbucksLocations = [NSMutableArray new];
        
        // Create annotations for each of the Starbucks and add them to the map
        for (MKMapItem *mapItem in response.mapItems) {
            MKPointAnnotation *point = [MKPointAnnotation new];
            point.coordinate = mapItem.placemark.coordinate;
            point.title = mapItem.placemark.locality;
            point.subtitle = [mapItem.placemark.addressDictionary valueForKey:@"Street"];
            
            StarbucksLocation *starbucksLocation = [StarbucksLocation new];
            starbucksLocation.mapItem = mapItem;
            starbucksLocation.annotation = point;
            
            [self.starbucksLocations addObject:starbucksLocation];
            
            [self.mapView addAnnotation:starbucksLocation.annotation];
        }
        
        // Show the first Starbucks
        if (self.starbucksLocations.count > 0) {
            self.currentStarbucksIndex = 0;
            [self showStarbucksLocation:self.currentStarbucksIndex];
        }
    }];
    
}

// While showing a Starbucks, ensure that the user's location is also visible so that he can understand the Starbucks location more easily
- (void)showStarbucksLocation:(int)locationIndex {
    
    StarbucksLocation *location = self.starbucksLocations[locationIndex];
    
    MKMapItem *mapItem = location.mapItem;
    MKCoordinateRegion region = {{0.0,0.0}, {0.0,0.0}};
    region.center.latitude = mapItem.placemark.coordinate.latitude;
    region.center.longitude = mapItem.placemark.coordinate.longitude;
    region.span.longitudeDelta = 0.15f;
    region.span.latitudeDelta = 0.15f;
    self.changingStarbucksLocation = YES;
//    [self.mapView setRegion:region animated:YES];
    
    [self.mapView showAnnotations:@[location.annotation, self.userLocationAnnotation] animated:YES];

}

// Remove the pop-ups shown when the location service have been enabled for the app
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if ([self.reachability currentReachabilityStatus] != NotReachable) {
        if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorized) {
            [self.alertView dismissWithClickedButtonIndex:-1 animated:YES];
        }
    }
}


@end
