#!/bin/bash

SOURCE_NAME="UnknownSources"
VERSION="$(git describe --tags --long --always --match '[0-9]*.*')"
ZVERSION="v$VERSION"

init_build() {
    echo " - Creating directory structure"
    rm -rf build || exit 1
    mkdir -p build/RulebookShared || exit 1
    mkdir -p dist || exit 1

    echo " - Linking in external files"
    ln -s ../fonts build/fonts || exit 1
    ln -s ../resources build/resources || exit 1
    ln -s ../../RulebookShared/fonts build/RulebookShared/fonts || exit 1

    echo " - Copying in .lyx files"
    cp *.lyx build || exit 1
    cp RulebookShared/*.lyx build/RulebookShared || exit 1

    echo " - Disabling all branches"
    sed -i -e '/\\branch .*/,+1s/\\selected.*/\\selected 0/' build/*.lyx build/RulebookShared/*.lyx || exit 1

    case $1 in
    release)
        activate_branch RulebookShared/Format_Common Release || exit 1
        FILE_MARKER=""
        ZIP_FILE_BIND=""
    ;;
    playtest)
        activate_branch RulebookShared/Format_Common Playtest || exit 1
        FILE_MARKER=" Playtest"
        ZIP_FILE_BIND=" - Playtest"
    ;;
    ci)
        if [ ! -z "$GITHUB_RUN_NUMBER" ]; then
            ZVERSION="r$GITHUB_RUN_NUMBER"
        fi
        
        activate_branch RulebookShared/Format_Common CiBuild || exit 1
        FILE_MARKER=" Draft"
        ZIP_FILE_BIND=" - Draft"
    ;;
    *)
        FILE_MARKER=" Draft"
        ZIP_FILE_BIND=" - Draft"
    ;;
    esac
}

activate_branch() {
    sed -i -e '/\\branch '$2'.*/,+1s/\\selected.*/\\selected 1/' "build/$1.lyx" || exit 1
}
render_pdf() {
    # Creates the direct output PDF
    lyx -v "build/$1.lyx" -E pdf4 "build/$1_Temp.pdf" || exit 1
    
    # Encrypt and recompress the PDF. This isn't really used for any real security, it's just here to avoid accidental modification.
    # Also to encourge anyone who wants to fork or do other weird stuff to *actually* use LyX instead of some weird PDF editor...
    qpdf "build/$1_Temp.pdf" "build/$1.pdf" \
        --compress-streams=y --object-streams=generate --coalesce-contents \
        --encrypt "" "pls dont do anything weird with the password :( :(" 256 \
        --extract=y --assemble=n --form=n --annotate=n --modify-other=n --print=full --modify=none --cleartext-metadata "${@:4}" -- || exit 1
    cp "build/$1.pdf" "build/out/$2$3.pdf" || exit 1
}
create_archive() {
    cd build/out
    zip -r "$1.zip" * || exit 1
    mv "$1.zip" ../../dist || exit 1
    cd ../..
}
create_source_archive() {
    mkdir "build/$SOURCE_NAME-$VERSION" || exit 1
    
    # Copy repository files
    cp -r fonts/ resources/ build.sh *.md *.lyx "build/$SOURCE_NAME-$VERSION" || exit 1
    rm "build/$SOURCE_NAME-$VERSION/resources"/*.xcf || exit 1
    
    # Copy shared files
    mkdir "build/$SOURCE_NAME-$VERSION/RulebookShared" || exit 1
    cp -r RulebookShared/fonts/ RulebookShared/*.sh RulebookShared/*.md RulebookShared/*.lyx "build/$SOURCE_NAME-$VERSION/RulebookShared" || exit 1
    
    # Create gitHeadInfo.gin file
    mkdir "build/$SOURCE_NAME-$VERSION/.git" || exit 1
    cp -r .git/gitHeadInfo.gin "build/$SOURCE_NAME-$VERSION/.git" || exit 1

    cd build
    tar --xz -cvf "$1.tar.xz" "$SOURCE_NAME-$VERSION" || exit 1
    mv "$1.tar.xz" ../dist || exit 1
    cd ..
}
