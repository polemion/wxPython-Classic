/////////////////////////////////////////////////////////////////////////////
// Name:        _image.i
// Purpose:     SWIG definitions for wxImage and such
//
// Author:      Robin Dunn
//
// Created:     25-Sept-2000
// RCS-ID:      $Id$
// Copyright:   (c) 2003 by Total Control Software
// Licence:     wxWindows license
/////////////////////////////////////////////////////////////////////////////

// Not a %module


//---------------------------------------------------------------------------

%{
#include "wx/wxPython/pyistream.h"
%}

//---------------------------------------------------------------------------

enum {
    wxIMAGE_ALPHA_TRANSPARENT,
    wxIMAGE_ALPHA_THRESHOLD,
    wxIMAGE_ALPHA_OPAQUE
};


//---------------------------------------------------------------------------
%newgroup

DocStr(wxImageHandler,
"This is the base class for implementing image file loading/saving, and
image creation from data. It is used within `wx.Image` and is not
normally seen by the application.", "");
class wxImageHandler : public wxObject {
public:
    // wxImageHandler();    Abstract Base Class
    wxString GetName();
    wxString GetExtension();
    long GetType();
    wxString GetMimeType();

    //bool LoadFile(wxImage* image, wxInputStream& stream);
    //bool SaveFile(wxImage* image, wxOutputStream& stream);
    //virtual int GetImageCount( wxInputStream& stream );
    //bool CanRead( wxInputStream& stream );

    bool CanRead( const wxString& name );

    void SetName(const wxString& name);
    void SetExtension(const wxString& extension);
    void SetType(long type);
    void SetMimeType(const wxString& mimetype);
};


//---------------------------------------------------------------------------

class wxImageHistogram /* : public wxImageHistogramBase */
{
public:
    wxImageHistogram();

    DocStr(MakeKey, "Get the key in the histogram for the given RGB values", "");
    static unsigned long MakeKey(unsigned char r,
                                 unsigned char g,
                                 unsigned char b);

    DocDeclAStr(
        bool, FindFirstUnusedColour(unsigned char *OUTPUT,
                                    unsigned char *OUTPUT,
                                    unsigned char *OUTPUT,
                                    unsigned char startR = 1,
                                    unsigned char startG = 0,
                                    unsigned char startB = 0 ) const,
        "FindFirstUnusedColour(int startR=1, int startG=0, int startB=0) -> (success, r, g, b)",
        "Find first colour that is not used in the image and has higher RGB
values than startR, startG, startB.  Returns a tuple consisting of a
success flag and rgb values.", "");

    %extend {
        DocStr(GetCount,
               "Returns the pixel count for the given key.  Use `MakeKey` to create a
key value from a RGB tripple.", "");
        unsigned long GetCount(unsigned long key) {
            wxImageHistogramEntry e = (*self)[key];
            return e.value;
        }

        DocStr(GetCountRGB,
               "Returns the pixel count for the given RGB values.", "");
        unsigned long GetCountRGB(unsigned char r,
                                  unsigned char g,
                                  unsigned char b) {
            unsigned long key = wxImageHistogram::MakeKey(r, g, b);
            wxImageHistogramEntry e = (*self)[key];
            return e.value;
        }
        
        DocStr(GetCountColour,
               "Returns the pixel count for the given `wx.Colour` value.", "");
        unsigned long GetCountColour(const wxColour& colour) {
            unsigned long key = wxImageHistogram::MakeKey(colour.Red(),
                                                          colour.Green(),
                                                          colour.Blue());
            wxImageHistogramEntry e = (*self)[key];
            return e.value;
        }
    }
    
};


//---------------------------------------------------------------------------

%{
    typedef unsigned char* buffer;
%}    

%typemap(in) (buffer data, int DATASIZE)
    { if (!PyArg_Parse($input, "t#", &$1, &$2)) SWIG_fail; }

%typemap(in) (buffer alpha, int ALPHASIZE)
    { if (!PyArg_Parse($input, "t#", &$1, &$2)) SWIG_fail; }

//---------------------------------------------------------------------------


class wxImage : public wxObject {
public:
    %typemap(out) wxImage*;    // turn off this typemap

    DocCtorStr(
        wxImage( const wxString& name, long type = wxBITMAP_TYPE_ANY, int index = -1 ),
        "", "");
    
    ~wxImage();

    // Alternate constructors
    DocCtorStrName(
        wxImage(const wxString& name, const wxString& mimetype, int index = -1),
        "", "",
        ImageFromMime);
    
    DocCtorStrName(
        wxImage(wxInputStream& stream, long type = wxBITMAP_TYPE_ANY, int index = -1),
        "", "",
        ImageFromStream);
    
    DocCtorStrName(
        wxImage(wxInputStream& stream, const wxString& mimetype, int index = -1 ),
        "", "",
        ImageFromStreamMime);
    
    %extend {
        %RenameDocCtor(
            EmptyImage,
            "Construct an empty image of a given size, optionally setting all
pixels to black.", "",
            wxImage(int width=0, int height=0, bool clear = true))
            {
                if (width > 0 && height > 0)
                    return new wxImage(width, height, clear);
                else
                    return new wxImage;
            }

        
       MustHaveApp(wxImage(const wxBitmap &bitmap));
        
        %RenameDocCtor(
            ImageFromBitmap,
            "Construct an Image from a `wx.Bitmap`.", "",
            wxImage(const wxBitmap &bitmap))
            {
                return new wxImage(bitmap.ConvertToImage());
            }

        %RenameDocCtor(
            ImageFromData,
            "Construct an Image from a buffer of RGB bytes.  Accepts either a
string or a buffer object holding the data and the length of the data
must be width*height*3.", "",
            wxImage(int width, int height, buffer data, int DATASIZE))
            {
                if (DATASIZE != width*height*3) {
                    wxPyErr_SetString(PyExc_ValueError, "Invalid data buffer size.");
                    return NULL;
                }
            
                // Copy the source data so the wxImage can clean it up later
                buffer copy = (buffer)malloc(DATASIZE);
                if (copy == NULL) {
                    wxPyBLOCK_THREADS(PyErr_NoMemory());
                    return NULL;
                }            
                memcpy(copy, data, DATASIZE);
                return new wxImage(width, height, copy, false);
            }

        
        %RenameDocCtor(
            ImageFromDataWithAlpha,
            "Construct an Image from a buffer of RGB bytes with an Alpha channel.
Accepts either a string or a buffer object holding the data and the
length of the data must be width*height*3.", "",
            wxImage(int width, int height, buffer data, int DATASIZE, buffer alpha, int ALPHASIZE))
            {
                if (DATASIZE != width*height*3) {
                    wxPyErr_SetString(PyExc_ValueError, "Invalid data buffer size.");
                    return NULL;
                }
                if (ALPHASIZE != width*height) {
                    wxPyErr_SetString(PyExc_ValueError, "Invalid alpha buffer size.");
                    return NULL;
                }

                // Copy the source data so the wxImage can clean it up later
                buffer dcopy = (buffer)malloc(DATASIZE);
                if (dcopy == NULL) {
                    wxPyBLOCK_THREADS(PyErr_NoMemory());
                    return NULL;
                }
                memcpy(dcopy, data, DATASIZE);
            
                buffer acopy = (buffer)malloc(ALPHASIZE);
                if (acopy == NULL) {
                    wxPyBLOCK_THREADS(PyErr_NoMemory());
                    return NULL;
                }
                memcpy(acopy, alpha, ALPHASIZE);
            
                return new wxImage(width, height, dcopy, acopy, false);
            }
    }

    // TODO: wxImage( char** xpmData );


    // Turn it back on again
    %typemap(out) wxImage* { $result = wxPyMake_wxObject($1, $owner); }


    void Create( int width, int height );
    void Destroy();

    wxImage Scale( int width, int height );
    wxImage ShrinkBy( int xFactor , int yFactor ) const ;
    wxImage& Rescale(int width, int height);

    // resizes the image in place
    wxImage& Resize( const wxSize& size, const wxPoint& pos, 
                     int r = -1, int g = -1, int b = -1 );
    
    void SetRGB( int x, int y, unsigned char r, unsigned char g, unsigned char b );

    %Rename(SetRGBRect,
            void, SetRGB( const wxRect& rect,
                          unsigned char r, unsigned char g, unsigned char b ));

    unsigned char GetRed( int x, int y );
    unsigned char GetGreen( int x, int y );
    unsigned char GetBlue( int x, int y );

    void SetAlpha(int x, int y, unsigned char alpha);
    unsigned char GetAlpha(int x, int y);
    bool HasAlpha();

    DocDeclStr(
        void , InitAlpha(),
        "Initializes the image alpha channel data. It is an error to call it if
the image already has alpha data. If it doesn't, alpha data will be by
default initialized to all pixels being fully opaque. But if the image
has a a mask colour, all mask pixels will be completely transparent.", "");


    DocDeclStr(
        bool , IsTransparent(int x, int y,
                             unsigned char threshold = wxIMAGE_ALPHA_THRESHOLD) const,
        "Returns True if this pixel is masked or has an alpha value less than
the spcified threshold.", "");
    
    
    // find first colour that is not used in the image and has higher
    // RGB values than <startR,startG,startB>
    DocDeclAStr(
        bool, FindFirstUnusedColour( byte *OUTPUT, byte *OUTPUT, byte *OUTPUT,
                                     byte startR = 0, byte startG = 0, byte startB = 0 ) const,
        "FindFirstUnusedColour(int startR=1, int startG=0, int startB=0) -> (success, r, g, b)",
        "Find first colour that is not used in the image and has higher RGB
values than startR, startG, startB.  Returns a tuple consisting of a
success flag and rgb values.", "");

    
    DocDeclStr(
        bool , ConvertAlphaToMask(byte threshold = wxIMAGE_ALPHA_THRESHOLD),
        "If the image has alpha channel, this method converts it to mask. All pixels
with alpha value less than ``threshold`` are replaced with mask colour and the
alpha channel is removed. Mask colour is chosen automatically using
`FindFirstUnusedColour`.

If the image image doesn't have alpha channel, ConvertAlphaToMask does
nothing.", "");
    

    DocDeclStr(
        bool , ConvertColourToAlpha( unsigned char r, unsigned char g, unsigned char b ),
        "This method converts an image where the original alpha information is
only available as a shades of a colour (actually shades of grey)
typically when you draw anti-aliased text into a bitmap. The DC
drawing routines draw grey values on the black background although
they actually mean to draw white with differnt alpha values.  This
method reverses it, assuming a black (!) background and white text.
The method will then fill up the whole image with the colour given.", "");
    

    
    // Set image's mask to the area of 'mask' that has <mr,mg,mb> colour
    bool SetMaskFromImage(const wxImage & mask,
                          byte mr, byte mg, byte mb);

//      void DoFloodFill (wxCoord x, wxCoord y,
//          const wxBrush & fillBrush,
//          const wxColour& testColour,
//          int style = wxFLOOD_SURFACE,
//          int LogicalFunction = wxCOPY /* currently unused */ ) ;

    static bool CanRead( const wxString& name );
    static int GetImageCount( const wxString& name, long type = wxBITMAP_TYPE_ANY );

    bool LoadFile( const wxString& name, long type = wxBITMAP_TYPE_ANY, int index = -1 );
    %Rename(LoadMimeFile, bool,  LoadFile( const wxString& name, const wxString& mimetype, int index = -1 ));

    bool SaveFile( const wxString& name, int type );
    %Rename(SaveMimeFile, bool,  SaveFile( const wxString& name, const wxString& mimetype ));

    %Rename(CanReadStream, static bool,  CanRead( wxInputStream& stream ));
    %Rename(LoadStream, bool,  LoadFile( wxInputStream& stream, long type = wxBITMAP_TYPE_ANY, int index = -1 ));
    %Rename(LoadMimeStream, bool,  LoadFile( wxInputStream& stream, const wxString& mimetype, int index = -1 ));

    bool Ok();
    int GetWidth();
    int GetHeight();

    %extend {
        wxSize GetSize() {
            wxSize size(self->GetWidth(), self->GetHeight());
            return size;
        }
    }

    wxImage GetSubImage(const wxRect& rect);

    // Paste the image or part of this image into an image of the given size at the pos
    //  any newly exposed areas will be filled with the rgb colour
    //  by default if r = g = b = -1 then fill with this image's mask colour or find and 
    //  set a suitable mask colour
    wxImage Size( const wxSize& size, const wxPoint& pos, 
                  int r = -1, int g = -1, int b = -1 ) const;
    
    wxImage Copy();
    void Paste( const wxImage &image, int x, int y );

    //unsigned char *GetData();
    //void SetData( unsigned char *data );

    %extend {
        DocStr(GetData,
               "Returns a string containing a copy of the RGB bytes of the image.", "");
        PyObject* GetData()
        {
            buffer data = self->GetData();
            int len = self->GetWidth() * self->GetHeight() * 3;
            PyObject* rv;
            wxPyBLOCK_THREADS( rv = PyString_FromStringAndSize((char*)data, len));
            return rv;
        }
        DocStr(SetData,
               "Resets the Image's RGB data from a buffer of RGB bytes.  Accepts
either a string or a buffer object holding the data and the length of
the data must be width*height*3.", "");
        void SetData(buffer data, int DATASIZE)
        {
            if (DATASIZE != self->GetWidth() * self->GetHeight() * 3) {
                wxPyErr_SetString(PyExc_ValueError, "Invalid data buffer size.");
                return;
            }            
            buffer copy = (buffer)malloc(DATASIZE);
            if (copy == NULL) {
                wxPyBLOCK_THREADS(PyErr_NoMemory());
                return;
            }            
            memcpy(copy, data, DATASIZE);
            self->SetData(copy, false);
            // wxImage takes ownership of copy...
        }


        DocStr(GetDataBuffer,
               "Returns a writable Python buffer object that is pointing at the RGB
image data buffer inside the wx.Image.", "");
        PyObject* GetDataBuffer()
        {
            buffer data = self->GetData();
            int len = self->GetWidth() * self->GetHeight() * 3;
            PyObject* rv;
            wxPyBLOCK_THREADS( rv = PyBuffer_FromReadWriteMemory(data, len) );
            return rv;
        }

        DocStr(SetDataBuffer,
               "Sets the internal image data pointer to point at a Python buffer
object.  This can save a copy of the data but you must ensure that the
buffer object lives longer than the wx.Image does.", "");
        void SetDataBuffer(buffer data, int DATASIZE)
        {
            if (DATASIZE != self->GetWidth() * self->GetHeight() * 3) {
                wxPyErr_SetString(PyExc_ValueError, "Invalid data buffer size.");
                return;
            }
            self->SetData(data, true);
        }



        DocStr(GetAlphaData,
               "Returns a string containing a copy of the alpha bytes of the image.", "");
        PyObject* GetAlphaData() {
            buffer data = self->GetAlpha();
            if (! data) {
                RETURN_NONE();
            } else {
                int len = self->GetWidth() * self->GetHeight();
                PyObject* rv;
                wxPyBLOCK_THREADS( rv = PyString_FromStringAndSize((char*)data, len) );
                return rv;
            }
        }

        DocStr(SetAlphaData,
               "Resets the Image's alpha data from a buffer of bytes.  Accepts either
a string or a buffer object holding the data and the length of the
data must be width*height.", ""); 
        void SetAlphaData(buffer alpha, int ALPHASIZE)
        {
            if (ALPHASIZE != self->GetWidth() * self->GetHeight()) {
                wxPyErr_SetString(PyExc_ValueError, "Invalid alpha buffer size.");
                return;
            }
            buffer acopy = (buffer)malloc(ALPHASIZE);
            if (acopy == NULL) {
                wxPyBLOCK_THREADS(PyErr_NoMemory());
                return;
            }
            memcpy(acopy, alpha, ALPHASIZE);
            self->SetAlpha(acopy, false);
            // wxImage takes ownership of acopy...
        }


        
        DocStr(GetDataBuffer,
               "Returns a writable Python buffer object that is pointing at the Alpha
data buffer inside the wx.Image.", "");
        PyObject* GetAlphaBuffer()
        {
            buffer data = self->GetAlpha();
            int len = self->GetWidth() * self->GetHeight();
            PyObject* rv;
            wxPyBLOCK_THREADS( rv = PyBuffer_FromReadWriteMemory(data, len) );
            return rv;
        }

        
        DocStr(SetDataBuffer,
               "Sets the internal image alpha pointer to point at a Python buffer
object.  This can save a copy of the data but you must ensure that the
buffer object lives longer than the wx.Image does.", "");
        void SetAlphaBuffer(buffer alpha, int ALPHASIZE)
        {
            if (ALPHASIZE != self->GetWidth() * self->GetHeight()) {
                wxPyErr_SetString(PyExc_ValueError, "Invalid alpha buffer size.");
                return;
            }
            self->SetAlpha(alpha, true);
        }
    }

    void SetMaskColour( unsigned char r, unsigned char g, unsigned char b );

    DocDeclAStr(
        /*bool*/ void , GetOrFindMaskColour( unsigned char *OUTPUT,
                                             unsigned char *OUTPUT,
                                             unsigned char *OUTPUT ) const,
        "GetOrFindMaskColour() -> (r,g,b)",
        "Get the current mask colour or find a suitable colour.", "");
    

    unsigned char GetMaskRed();
    unsigned char GetMaskGreen();
    unsigned char GetMaskBlue();
    void SetMask( bool mask = true );
    bool HasMask();

    wxImage Rotate(double angle, const wxPoint & centre_of_rotation,
                   bool interpolating = true, wxPoint * offset_after_rotation = NULL) const ;
    wxImage Rotate90( bool clockwise = true ) ;
    wxImage Mirror( bool horizontally = true ) ;

    void Replace( unsigned char r1, unsigned char g1, unsigned char b1,
                  unsigned char r2, unsigned char g2, unsigned char b2 );

    // convert to monochrome image (<r,g,b> will be replaced by white, everything else by black)
    wxImage ConvertToMono( unsigned char r, unsigned char g, unsigned char b ) const;

    void SetOption(const wxString& name, const wxString& value);
    %Rename(SetOptionInt, void,  SetOption(const wxString& name, int value));
    wxString GetOption(const wxString& name) const;
    int GetOptionInt(const wxString& name) const;
    bool HasOption(const wxString& name) const;

    unsigned long CountColours( unsigned long stopafter = (unsigned long) -1 );
    unsigned long ComputeHistogram( wxImageHistogram& h );

    static void AddHandler( wxImageHandler *handler );
    static void InsertHandler( wxImageHandler *handler );
    static bool RemoveHandler( const wxString& name );
    static wxString GetImageExtWildcard();


MustHaveApp(ConvertToBitmap);
MustHaveApp(ConvertToMonoBitmap);

    %extend {
        wxBitmap ConvertToBitmap(int depth=-1) {
            wxBitmap bitmap(*self, depth);
            return bitmap;
        }

        wxBitmap ConvertToMonoBitmap( unsigned char red,
                                      unsigned char green,
                                      unsigned char blue ) {
            wxImage mono = self->ConvertToMono( red, green, blue );
            wxBitmap bitmap( mono, 1 );
            return bitmap;
        }
    }

    %pythoncode { def __nonzero__(self): return self.Ok() }
};



///void wxInitAllImageHandlers();

%pythoncode {
    def InitAllImageHandlers():
        """
        The former functionality of InitAllImageHanders is now done internal to
        the _core_ extension module and so this function has become a simple NOP.
        """
        pass
}



// See also wxPy_ReinitStockObjects in helpers.cpp
%immutable;
const wxImage    wxNullImage;
%mutable;

//---------------------------------------------------------------------------

MAKE_CONST_WXSTRING(IMAGE_OPTION_FILENAME);
MAKE_CONST_WXSTRING(IMAGE_OPTION_BMP_FORMAT);
MAKE_CONST_WXSTRING(IMAGE_OPTION_CUR_HOTSPOT_X);
MAKE_CONST_WXSTRING(IMAGE_OPTION_CUR_HOTSPOT_Y);
MAKE_CONST_WXSTRING(IMAGE_OPTION_RESOLUTION);
MAKE_CONST_WXSTRING(IMAGE_OPTION_RESOLUTIONX);
MAKE_CONST_WXSTRING(IMAGE_OPTION_RESOLUTIONY);
MAKE_CONST_WXSTRING(IMAGE_OPTION_RESOLUTIONUNIT);
MAKE_CONST_WXSTRING(IMAGE_OPTION_QUALITY);

enum
{
    wxIMAGE_RESOLUTION_INCHES = 1,
    wxIMAGE_RESOLUTION_CM = 2
};


MAKE_CONST_WXSTRING(IMAGE_OPTION_BITSPERSAMPLE);
MAKE_CONST_WXSTRING(IMAGE_OPTION_SAMPLESPERPIXEL); 
MAKE_CONST_WXSTRING(IMAGE_OPTION_COMPRESSION);
MAKE_CONST_WXSTRING(IMAGE_OPTION_IMAGEDESCRIPTOR);

MAKE_CONST_WXSTRING(IMAGE_OPTION_PNG_FORMAT);
MAKE_CONST_WXSTRING(IMAGE_OPTION_PNG_BITDEPTH);

enum
{
    wxPNG_TYPE_COLOUR = 0,
    wxPNG_TYPE_GREY = 2,
    wxPNG_TYPE_GREY_RED = 3
};

enum
{
    wxBMP_24BPP        = 24, // default, do not need to set
    //wxBMP_16BPP      = 16, // wxQuantize can only do 236 colors?
    wxBMP_8BPP         =  8, // 8bpp, quantized colors
    wxBMP_8BPP_GREY    =  9, // 8bpp, rgb averaged to greys
    wxBMP_8BPP_GRAY    =  wxBMP_8BPP_GREY,
    wxBMP_8BPP_RED     = 10, // 8bpp, red used as greyscale
    wxBMP_8BPP_PALETTE = 11, // 8bpp, use the wxImage's palette
    wxBMP_4BPP         =  4, // 4bpp, quantized colors
    wxBMP_1BPP         =  1, // 1bpp, quantized "colors"
    wxBMP_1BPP_BW      =  2  // 1bpp, black & white from red
};


DocStr(wxBMPHandler,
"A `wx.ImageHandler` for \*.bmp bitmap files.", "");
class wxBMPHandler : public wxImageHandler {
public:
    wxBMPHandler();
};

DocStr(wxICOHandler,
"A `wx.ImageHandler` for \*.ico icon files.", "");
class wxICOHandler : public wxBMPHandler {
public:
    wxICOHandler();
};

DocStr(wxCURHandler,
"A `wx.ImageHandler` for \*.cur cursor files.", "");
class wxCURHandler : public wxICOHandler {
public:
    wxCURHandler();
};

DocStr(wxANIHandler,
"A `wx.ImageHandler` for \*.ani animated cursor files.", "");
class wxANIHandler : public wxCURHandler {
public:
    wxANIHandler();
};


//---------------------------------------------------------------------------

DocStr(wxPNGHandler,
"A `wx.ImageHandler` for PNG image files.", "");
class wxPNGHandler : public wxImageHandler {
public:
    wxPNGHandler();
};


DocStr(wxGIFHandler,
"A `wx.ImageHandler` for GIF image files.", "");
class wxGIFHandler : public wxImageHandler {
public:
    wxGIFHandler();
};


DocStr(wxPCXHandler,
"A `wx.ImageHandler` for PCX imager files.", "");
class wxPCXHandler : public wxImageHandler {
public:
    wxPCXHandler();
};


DocStr(wxJPEGHandler,
"A `wx.ImageHandler` for JPEG/JPG image files.", "");
class wxJPEGHandler : public wxImageHandler {
public:
    wxJPEGHandler();
};


DocStr(wxPNMHandler,
"A `wx.ImageHandler` for PNM image files.", "");
class wxPNMHandler : public wxImageHandler {
public:
    wxPNMHandler();
};

DocStr(wxXPMHandler,
"A `wx.ImageHandler` for XPM image.", "");
class wxXPMHandler : public wxImageHandler {
public:
    wxXPMHandler();
};

DocStr(wxTIFFHandler,
"A `wx.ImageHandler` for TIFF image files.", "");
class wxTIFFHandler : public wxImageHandler {
public:
    wxTIFFHandler();
};


#if wxUSE_IFF
DocStr(wxIFFHandler,
"A `wx.ImageHandler` for IFF image files.", "");
class wxIFFHandler : public wxImageHandler {
public:
    wxIFFHandler();
};
#endif

//---------------------------------------------------------------------------

%{
#include <wx/quantize.h>
%}

enum {
    wxQUANTIZE_INCLUDE_WINDOWS_COLOURS,
//    wxQUANTIZE_RETURN_8BIT_DATA,
    wxQUANTIZE_FILL_DESTINATION_IMAGE
};


DocStr(wxQuantize,
       "Performs quantization, or colour reduction, on a wxImage.", "");

class wxQuantize /*: public wxObject */
{
public:
    
    %extend {
        DocStr(
            Quantize,
            "Reduce the colours in the source image and put the result into the
destination image, setting the palette in the destination if
needed. Both images may be the same, to overwrite the source image.", "
:todo: Create a version that returns the wx.Palette used.");
    
        static bool Quantize(const wxImage& src, wxImage& dest, int desiredNoColours = 236,
                             int flags = wxQUANTIZE_INCLUDE_WINDOWS_COLOURS|wxQUANTIZE_FILL_DESTINATION_IMAGE)
        {
                return wxQuantize::Quantize(src, dest, 
                                            //NULL, // palette
                                            desiredNoColours,
                                            NULL, // eightBitData
                                            flags);
        }
    }
};


//---------------------------------------------------------------------------
