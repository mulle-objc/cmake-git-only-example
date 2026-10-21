#import <MulleObjC/MulleObjC.h>
#import <stdio.h>


@interface Greeter : NSObject
{
   char   *_name;
}

- (id) initWithName:(char *) name;
- (void) greet;

@end


@implementation Greeter

- (id) initWithName:(char *) name
{
   _name = name;
   return( self);
}

- (void) greet
{
   printf( "Hello, %s\n", _name);
}

- (void) dealloc
{
   [super dealloc];
}

@end


int   main( int argc, const char *argv[])
{
   NSAutoreleasePool   *pool;
   Greeter             *greeter;

   pool    = [NSAutoreleasePool new];
   greeter = [[[Greeter alloc] initWithName:"VfL Bochum 1848"] autorelease];
   [greeter greet];
   [pool release];

   return( 0);
}
