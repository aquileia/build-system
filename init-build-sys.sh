#! /bin/bash
#
# Requires: Bash, gettext, and wmlxgettext (the Perl version)
#
# lbundle.py:
# http://websvn.kde.org/*checkout*/trunk/l10n-support/scripts/lbundle-check.py
#
# wmlxgettext (Perl):
# http://svn.gna.org/viewcvs/*checkout*/wesnoth/trunk/utils/wmlxgettext
#
#  Copyright © 2010–2012 by Steven Panek <Majora700@gmail.com>
#  Part of the Wesnoth Campaign Translations project
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License version 2
#  or at your option any later version.
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY.
#
#  See the COPYING file for more details.
#

__CMDLINE=$*

# Spit out help
if [ "$1" = "" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	cat <<- EOD
		Usage: init-build-sys.sh [options] [version] ADDON_DIRECTORY OUTPUT_DIRECTORY

		init-build-sys.sh generates the translation build system for addons as well as po files.

		ADDON_DIRECTORY represents the name of the directory that contains the targeted addon, while OUTPUT_DIRECTORY represents the directory where the "po" directory and a few other files belonging to the build system will be dumped.

		Options:

		--force         | -f       Overwrite files/directories normally created by this script, if any exist.
		--update        | -u       Update the files created by this script, do not perform actions that should only happen once.
		--help          | -h       Displays this information and exits.
		--verbose       | -v       Enables extra information.

		Supported versions:

		--1.0
		--1.2
		--1.4
		--1.6
		--1.8
		--1.10
		--trunk

		Please note that 'support' for 1.0 and 1.2 is merely there for fun, thus we do not know if it truly works; if you find that what this script generates for 1.0/1.2 does not work, do not get mad.

		This script should be run in the directory that contains the target addon's directory.

		Report any issues to Espreon.


		NOTES FOR ACTUAL USAGE:
		-run the script *from the addon translation repo's root*, that is Invasion_from_the_Unknown-1.10 or the like
		-invoke it as path/to/init-build-sys.sh --1.10 Invasion_from_the_Unknown .
		-DO NOT FORGET THE PERIOD, or it might decide to write to your home directory instead
	EOD
	exit
fi

# Macros/whatevers that check for textdomain_check and textdomain_check_trunk
# Syntax: (name) () (url string)
need_thingy()
{
    echo "$1 was not found in your PATH; please put it in your PATH.

If you do not have $1, you can get it from here: $2"
    echo "Aborting..."
    exit 7
}

check_for_thingy()
{
    type -P $1 &>/dev/null || need_thingy $1 $2
}

need_perl_wmlxgettext()
{
    echo "The Perl version of wmlxgettext was not found in your PATH; please put it in your PATH.

If you do not have it, you can get it from here: http://svn.gna.org/viewcvs/*checkout*/wesnoth/trunk/utils/wmlxgettext"
    echo "Aborting..."
    exit 7
}

# Yes, I know that this is a bit hacky, but... yeahz...
check_for_perl_wmlxgettext()
{
    wmlxgettext | head -n 3 | grep "PACKAGE VERSION" > /dev/null || need_perl_wmlxgettext
}

# Checks to see if something the script is about to create exists; if that something exists, and if --force/-f is
# not enabled, abort
check_for_file()
{
    if [ "${UPDATE}" = "yes" ]; then
        if [ ! -e "$1" ]; then
            echo "File/directory '$1' does not exist while updating; aborting..."
            exit 1
        fi
    elif [ "${FORCE}" = "no" ]; then
        if [ -e "$1" ]; then
            echo "File/directory '$1' exists; --force/-f not enabled; aborting..."
            exit 1
        fi
    fi
}

# Checks if the script is allowed to write to (and maybe clobber) a file.
# It is not if the update flag is set and the file exists
check_create() {
    if [ -e $1 ]; then
        if [ "${UPDATE}" = "yes" ]; then
            false;
        else
            true;
        fi
    else
        true;
    fi
}

verbose_message()
{
    if [ "${VERBOSE}" = "yes" ]; then
       echo "VERBOSE: $1"
    fi
}

check_for_perl_wmlxgettext
# check_for_thingy "lbundle-check.py" "http://websvn.kde.org/*checkout*/trunk/l10n-support/scripts/lbundle-check.py"

# Set some variables

# Find the location of this script and the directory that contains it
PATH_TO_ME=$(readlink -f $0)
MY_DIRECTORY="`dirname $PATH_TO_ME`"

# Disable verbosity by default
VERBOSE="no"

# Disable force by default
FORCE="no"

# Disable update by default
UPDATE="no"

# Input/output
OUTPUT_DIRECTORY="null"
INPUT_DIRECTORY="null"

# Name of addon directory
ADDON_DIRECTORY_NAME="."

# Version on which the target addon runs
VERSION="null"

# Parse parameters
while [ "${1}" != "" ] || [ "${1}" = "--help" ] || [ "${1}" = "-h" ]; do

    # Determine whether or not to enable force
    if [ "${1}" = "--force" ] || [ "${1}" = "-f" ]; then
        FORCE="yes"
        shift

    elif [ "${1}" = "--update" ] || [ "${1}" = "-u" ]; then
        UPDATE="yes"
        shift

    # Determine whether or not to enable more information
    elif [ "${1}" = "--verbose" ] || [ "${1}" = "-v" ]; then
        VERBOSE="yes"
        shift

    # Set version that the target addon uses
    # Yes, I am such a noob
    elif [ "${1}" = "--trunk" ]; then
        VERSION="trunk"
        shift

    elif [ "${1}" = "--1.10" ]; then
        VERSION="1.10"
        shift

    elif [ "${1}" = "--1.8" ]; then
        VERSION="1.8"
        shift

    elif [ "${1}" = "--1.6" ]; then
        VERSION="1.6"
        shift

    elif [ "${1}" = "--1.4" ]; then
        VERSION="1.4"
        shift

    elif [ "${1}" = "--1.2" ]; then
        VERSION="1.2"
        shift

    elif [ "${1}" = "--1.0" ]; then
        VERSION="1.0"
        shift

    else

        # Assign the path to the current working directory to INITIAL_DIRECTORY
        INITIAL_DIRECTORY="${PWD}"

        # Assign the path of the input directory and the addon directory's name to variables
        cd ${1} && INPUT_DIRECTORY="$PWD" && ADDON_DIRECTORY_NAME="${1}"
        cd $INITIAL_DIRECTORY
        shift

        # Now, assign the path of the output directory to a variable
        # If the desired output directory does not exist...
        if ! [ -e "$1" ]; then
            verbose_message "'$1' does not exist... creating '$1'..."
            mkdir $1
        fi
        cd ${1} && OUTPUT_DIRECTORY="$PWD"
        cd $INITIAL_DIRECTORY
        shift
    fi
done

# Information enabled by --verbose/-v
if [ "${VERBOSE}" = "yes" ]; then
echo ""
echo "VERBOSE:"
echo "Version used by addon: $VERSION"
echo "Addon directory name: $ADDON_DIRECTORY_NAME"
echo "Input directory: $INPUT_DIRECTORY"
echo "Output directory: $OUTPUT_DIRECTORY"
echo "Path to script: $PATH_TO_ME"
echo "Path to directory that contains this script: $MY_DIRECTORY"

echo ""
fi

verbose_message "Including the 'lang-codes' file, which contains the language codes..."
# Include the file that contains the lang codes
source $MY_DIRECTORY/language-codes

# Move templates to the destination
echo ""
echo "Creating the build system in $OUTPUT_DIRECTORY..."

# Check to see if a 'po' directory already exists
check_for_file "$OUTPUT_DIRECTORY/po"

# Move templates to destination
cp -rf $MY_DIRECTORY/templates/* $OUTPUT_DIRECTORY/

# Enter output directory
echo "Entering $OUTPUT_DIRECTORY..."
echo ""
cd $OUTPUT_DIRECTORY

check_for_file "po/LINGUAS"
echo "Creating 'LINGUAS' in $OUTPUT_DIRECTORY/po..."
echo $LINGUAS > $OUTPUT_DIRECTORY/po/LINGUAS

# Replace placeholders with the value of ADDON_DIRECTORY_NAME
echo ""
echo "Replacing placeholder value 'foobar' with '$ADDON_DIRECTORY_NAME' using 'sed' in..."
echo "... '$OUTPUT_DIRECTORY/campaign.def'..."
sed -i s/foobar/$ADDON_DIRECTORY_NAME/g $OUTPUT_DIRECTORY/campaign.def
echo "... '$OUTPUT_DIRECTORY/po/Makefile'..."
sed -i s/foobar/$ADDON_DIRECTORY_NAME/g $OUTPUT_DIRECTORY/po/Makefile

# Enter the output directory
echo ""
echo "Entering '$OUTPUT_DIRECTORY'..."
cd $OUTPUT_DIRECTORY

# Merge stuff from the target addon with the pot using wmlxgettext
if [ "${UPDATE}" = "no" ]; then
    echo ""
    echo "Generating the pot using wmlxgettext..."
    wmlxgettext --domain=wesnoth-$ADDON_DIRECTORY_NAME --directory=. `sh $OUTPUT_DIRECTORY/po/FINDCFG` > $OUTPUT_DIRECTORY/po/wesnoth-$ADDON_DIRECTORY_NAME.pot

    verbose_message "Clearing the Report-Msgid-Bugs-To field..."
    # Clear the Report-Msgid-Bugs-To field
    sed -i 's/Report-Msgid-Bugs-To: http:\/\/bugs.wesnoth.org\//Report-Msgid-Bugs-To: /g' $OUTPUT_DIRECTORY/po/wesnoth-$ADDON_DIRECTORY_NAME.pot
fi

# Generate Makefile
echo ""
echo "Generating po/Makefile"
make setup
echo "Clean up some"
make mostlyclean

# Enter 'po'
echo ""
echo "Entering '$OUTPUT_DIRECTORY/po'..."
cd $OUTPUT_DIRECTORY/po

# Generate po files
echo ""
echo "Generating po files..."
verbose_message "... with 'for i in `cat $OUTPUT_DIRECTORY/po/LINGUAS`; do msginit -l $i --no-translator --input $OUTPUT_DIRECTORY/po/wesnoth-$ADDON_DIRECTORY_NAME.pot; done'..."
for i in `cat $OUTPUT_DIRECTORY/po/LINGUAS`; do
    if check_create $OUTPUT_DIRECTORY/po/$i.po; then
        msginit -l $i --no-translator --input $OUTPUT_DIRECTORY/po/wesnoth-$ADDON_DIRECTORY_NAME.pot;
    #else
    #    echo "not creating ${OUTPUT_DIRECTORY}/po/${i}.po because it exists and we're in update mode"
    fi
done

if [ "${UPDATE}" = "no" ]; then
    # Hack to generate en_GB.po and en@shaw.po files without automatic translations
    echo ""
    echo "Generating en_GB.po and en@shaw.po files without automatic translations..."
    rm -f $OUTPUT_DIRECTORY/po/en_GB.po
    rm -f $OUTPUT_DIRECTORY/po/en@shaw.po
    # Copy de.po, for it has similar plurals info
    cp $OUTPUT_DIRECTORY/po/de.po $OUTPUT_DIRECTORY/po/en_GB.po
    cp $OUTPUT_DIRECTORY/po/de.po $OUTPUT_DIRECTORY/po/en@shaw.po
    # Replace 'de' with the proper locales within the files
    sed -i 's/\"Language: de\\n\"/\"Language: en_GB\\n\"/g' $OUTPUT_DIRECTORY/po/en_GB.po
    sed -i 's/\"Language: de\\n\"/\"Language: en@shaw\\n\"/g' $OUTPUT_DIRECTORY/po/en@shaw.po
fi

# Hack to ensure that fur_IT.po and nb_NO.po are made
echo ""
echo "Renaming fur.po and nb.po..."
if check_create $OUTPUT_DIRECTORY/po/fur_IT.po; then
    mv $OUTPUT_DIRECTORY/po/fur.po fur_IT.po
    sed -i 's/\"Language: fur\\n\"/\"Language: fur_IT\\n\"/g' $OUTPUT_DIRECTORY/po/fur_IT.po
fi
if check_create $OUTPUT_DIRECTORY/po/nb_NO.po; then
    mv $OUTPUT_DIRECTORY/po/nb.po nb_NO.po
    sed -i 's/\"Language: nb\\n\"/\"Language: nb_NO\\n\"/g' $OUTPUT_DIRECTORY/po/nb_NO.po
fi

# Fix plurals info for Irish
echo ""
echo "Fixing plurals info for Irish..."
sed -i 's/\"Plural-Forms: nplurals=3; plural=n==1 ? 0 : n==2 ? 1 : 2;\\n\"/"Plural-Forms: nplurals=5; plural=n==1 ? 0 : n==2 ? 1 : n<7 ? 2 : n<11 ? 3 : 4;\\n"/g' $OUTPUT_DIRECTORY/po/ga.po

# Add plurals info for Old English
if [ "${UPDATE}" = "no" ]; then
    echo ""
    echo "Adding plurals info for Old English..."
    sed -i 's/\(Language: ang.*\\n"\)/&\n"Plural-Forms: nplurals=3; plural=n==1 ? 0 : n==2 ? 1 : 2;\\n"/' $OUTPUT_DIRECTORY/po/ang.po
    sed -i 's/\(Language: ang@latin.*\\n"\)/&\n"Plural-Forms: nplurals=3; plural=n==1 ? 0 : n==2 ? 1 : 2;\\n"/' $OUTPUT_DIRECTORY/po/ang@latin.po
fi

# Kill cruft
echo ""
echo "Killing cruft..."
rm -f $OUTPUT_DIRECTORY/config.status
rm -f $OUTPUT_DIRECTORY/po/*gmo

# Done!
echo ""
echo "Done."
