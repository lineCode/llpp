# builds "hard" prerequisites and llpp
set -e

jobs=1
while getopts j: opt; do
    case "$opt" in
        j) jobs="$OPTARG";;
        ?)
        printf "usage: $0 [-j N] [opt]\n";
        exit 1;;
    esac
done
shift $((OPTIND - 1))

mkdir -p 3rdp
cd 3rdp
root=$(pwd)

lablgl=http://wwwfun.kurims.kyoto-u.ac.jp/soft/lsl/dist/lablgl-1.04.tar.gz
mupdf=git://git.ghostscript.com/mupdf.git
mupdf3p=http://mupdf.com/download/mupdf-thirdparty-2012-01-27.zip
mupdfrev=bbfe635555dce16858403706e2031dd3bfa1a9f1

test -d lablGL-1.04 || (wget -nc $lablgl && tar -xzf lablgl-1.04.tar.gz)
if ! test -f mupdf-$mupdfrev.tgz; then
    wget -nc \
       "http://git.ghostscript.com/?p=mupdf.git;a=snapshot;h=$mupdfrev;sf=tgz" \
       -O mupdf-$mupdfrev.tgz
    tar xfz mupdf-$mupdfrev.tgz
fi

test -d mupdf/thirdparty || \
    (wget -nc $mupdf3p && unzip -d mupdf $(basename $mupdf3p))

make=$(gmake -v >/dev/null 2>&1 && echo gmake || echo make)

(cd lablGL-1.04 \
    && sed '17c\
XLIBS = -lX11' Makefile.config.linux.mdk > Makefile.config \
    && $make lib libopt \
    && $make install \
            BINDIR=$root/bin \
            LIBDIR=$root/lib/ocaml \
            DLLDIR=$root/lib/ocaml/stublibs \
            INSTALLDIR=$root/lib/ocaml/lablGL)

(cd mupdf && $make -j "$jobs" build=release)

cd ..

srcpath=$(dirname $0)

sh $srcpath/mkhelp.sh $srcpath/keystoml.ml $srcpath/KEYS > help.ml

tp=$root/mupdf/thirdparty

ccopt="-O"
ccopt="$ccopt -I $tp/jbig2dec"
ccopt="$ccopt -I $tp/jpeg-8d"
ccopt="$ccopt -I $tp/freetype-2.4.8/include"
ccopt="$ccopt -I $tp/openjpeg-1.4/libopenjpeg"
ccopt="$ccopt -I $tp/zlib-1.2.5"
ccopt="$ccopt -I $root/mupdf/fitz -I $root/mupdf/pdf -I $root/mupdf/xps"
ccopt="$ccopt -I $root/mupdf/cbz"

ccopt="$ccopt -include ft2build.h -D_GNU_SOURCE"

cclib="$cclib -L$root/mupdf/build/release"
cclib="$cclib -lfitz"
cclib="$cclib -lz -ljpeg -lopenjpeg -ljbig2dec -lfreetype"
cclib="$cclib -lX11"

echo Building llpp...
if test "$1" = "opt"; then
    cclib="$cclib -lpthread"
    test -x $(type -p ocamlopt.opt) && comp=ocamlopt.opt || comp=ocamlopt
    $comp -c -o link.o -ccopt "$ccopt" $srcpath/link.c
    $comp -c -o help.cmx help.ml
    $comp -c -o wsi.cmi $srcpath/wsi.mli
    $comp -c -o wsi.cmx $srcpath/wsi.ml
    $comp -c -o parser.cmx $srcpath/parser.ml
    $comp -c -o main.cmx -I $root/lib/ocaml/lablGL $srcpath/main.ml

    $comp -o llpp                       \
        -I $root/lib/ocaml/lablGL       \
        str.cmxa unix.cmxa lablgl.cmxa  \
        link.o                          \
        -cclib "$cclib"                 \
        help.cmx                        \
        parser.cmx                      \
        wsi.cmx                         \
        main.cmx
else
    test -x $(type -p ocamlc.opt) && comp=ocamlc.opt || comp=ocamlc
    $comp -c -o link.o -ccopt "$ccopt" $srcpath/link.c
    $comp -c -o help.cmo help.ml
    $comp -c -o wsi.cmi $srcpath/wsi.mli
    $comp -c -o wsi.cmo $srcpath/wsi.ml
    $comp -c -o parser.cmo $srcpath/parser.ml
    $comp -c -o main.cmo -I $root/lib/ocaml/lablGL $srcpath/main.ml

    $comp -custom -o llpp            \
        -I $root/lib/ocaml/lablGL    \
        str.cma unix.cma lablgl.cma  \
        link.o                       \
        -cclib "$cclib"              \
        help.cmo                     \
        parser.cmo                   \
        wsi.cmo                      \
        main.cmo
fi
echo All done
