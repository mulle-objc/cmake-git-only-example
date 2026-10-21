#import <MulleWebFoundation/MulleWebFoundation.h>


int   main( int argc, const char *argv[])
{
   NSString   *s;
   NSData     *data;
   NSString   *base64;

   s = @"VfL Bochum 1848";

   mulle_printf( "%@\n", s);

   // Exercise the MulleBase64 category amalgamated into MulleWebFoundation:
   // encode the string's UTF-8 bytes and print the base64 text, proving the
   // add_subdirectory-built library links and its NSData(Base64) category
   // registered with the runtime.
   data   = [s dataUsingEncoding:NSUTF8StringEncoding];
   base64 = [data base64EncodedDescription];
   mulle_printf( "%@\n", base64);

   return( 0);
}
