#!/usr/bin/env bash

# GitHub: @captam3rica
VERSION=1.2.1

###############################################################################
#
# This Insight Software is provided by Insight on an "AS IS" basis.
#
# INSIGHT MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE, REGARDING THE INSIGHT SOFTWARE OR ITS USE AND
# OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
#
# IN NO EVENT SHALL INSIGHT BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
# MODIFICATION AND/OR DISTRIBUTION OF THE INSIGHT SOFTWARE, HOWEVER CAUSED
# AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
# STRICT LIABILITY OR OTHERWISE, EVEN IF INSIGHT HAS BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
###############################################################################
#
#   DESCRIPTION
#
#       This script is designed to make the implementation of DEPNotify very
#       easy with limited scripting knowledge. The section below has variables
#       that may be modified to customize the end-user experience. DO NOT
#       modify things in or below the CORE LOGIC area unless major testing and
#       validation is performed.
#
###############################################################################
#
#   CHANGELOG
#
#   Version - v1.0.0
#
#       - Modified from Jamf's DEPNotify-Starter script found here
#         https://github.com/jamf/DEPNotify-Starter
#       - Initial release
#       - Converted a number of the features in this script to functions.
#       - A secondary log file is generated at /Library/Logs
#           - enrollment-<date>.log
#
#   Version - v1.0.1
#
#       - Added check within the check_jamf_connect_login function to attempt
#         an installation of Jamf Connect Login if after 10 seconds the Jamf
#         Connect Login binary is not found.
#
#   Version - v1.0.2
#
#       - Moved the policy array section closer to the top of the script to
#         make it a little easier to modify later.
#
#   Version - v1.0.3
#
#       - Added functionality to rename Mac
#       - Added function that calls jamf recon
#       - Added DEPNotiy status for FaultVault check and submitting device
#         inventory to Jamf console.
#
#   Version - v1.0.4
#
#       - Added fix for Wi-Fi switching over before the end of enrollment.
#           - Added funtion to create an enrollment complete stub file. Once the
#             stub is laid down the Mac will check in.
#           - Added an accompanying Extension attribute that checks for the
#             enrollment complete stub.
#           - The Mac will then be moved to an  Ernollment Complete smart
#             group. This Smart group has the SCEP/Wi-Fi/Certs configuration
#             profile Scoped to it.
#           - This is all in an effort to control when the configuration profile
#             is installed on the device.
#
#   Version - v1.0.5
#
#       - Added ability to cleanup DEPNotify and the dependencies that are left
#         behind once the deployment process is over.
#       - calls a Jamf Pro policy containing a script
#
#   Version - v1.0.6
#
#       - Additional code refactoring done.
#       - Added ability to check for the dep-notify-enrollment daemon to see
#         if it is running before starting the DEPNotify process.
#       - Added Jamf policy to policy array that creates a local administrator
#         account on the Mac.
#
#   Version - 1.1
#
#       - Added ability to update the username assigned in Jamf computer
#         inventory record.
#           - calls a policy tied to a script that will determine if device was
#             enrolled via UIE or Automated Enrollment.
#           - This functionality can be toggled on with the variable
#             UPDATE_USERNAME_INVENTORY_RECORD below.
#
#   Version 1.2
#
#       - Added the ability to enable cheching for Jamf Connect Login with the
#         JAMF_CONNECT_ENABLED varilble. This variable is assigned to the Jamf
#         script parameter option number 11. Set the option to true else it
#         will remain false and assume that we are not using Jamf Connect.
#
#   Version 1.2.1
#
#       - Refactoring to make the script a little more portable.
#       - Added additional functionality to the is_jamf_enrollment_complete
#         function to check for the jamf.log then look in the log to see if
#         the enrollmentComplete string is present.
#
###############################################################################

#####################################################################captam3rica
# TESTING MODE
###############################################################################
# The TESTING_MODE flag will enable the following things to change:
#   - Auto removal of BOM files to reduce errors
#   - Sleep commands instead of policies or other changes being called
#   - Quit Key set to command + control + x

TESTING_MODE=true # Can be set to true or false


###############################################################################
# POLICY ARRAY VARIABLE TO MODIFY
###############################################################################
# The policy array must be formatted "Progress Bar text,customTrigger". These
# will be run in order as they appear below.
#
# Where applicable, updated the array with applications that are being deployed
# from Jamf during device enrollment. If the application already exists on the
# device then we want to skip that app. This can happen is cases like re-
# enrollment or if the device is pre-existing when the device is not wiped
# prior to enrolling.
POLICY_ARRAY=(
    # "Installing Google Chrome Browser,google-chrome"

)


################################################################################
# JAMF CONNECT
################################################################################
# If Jamf Connect is being used set the 11th script parameter to true
JAMF_CONNECT_ENABLED=false


################################################################################
# UPDATE USERNAME INVENTORY RECORD
################################################################################
# This functionality requires that the update-username-inventory-record.sh
# script be uploaded to Jamf and called as a policy.
#
# A copy of the script can be found here: https://github.com/captam3rica/Scripts/blob/master/Jamf/update-username-inventory-record.sh
#
# If the user is created during Automated enrollment the Jamf Pro inventory
# record is updated to include this username.
#
# If the Mac is enrolled via User-Initiated enrollment the script first
# checks to see if the Jamf inventory record needs to be updated with the
# current logged in user. Next, the script checks the currently logged in
# user and the username assigned in Jamf to see if they match.  If desired,
# the script will update the Jamf Pro inventory record with the current local
# username. Otherwise, this information is logged for later review.
UPDATE_USERNAME_INVENTORY_RECORD=false


################################################################################
# GENERAL APPEARANCE
################################################################################

# Flag the app to open fullscreen or as a window
FULLSCREEN=true # Set variable to true or false

# Banner image can be 600px wide by 100px high. Images will be scaled to fit
# If this variable is left blank, the generic image will appear. If using
# custom Self Service branding, please see the Customized Self Service Branding
# area below.

BANNER_IMAGE_PATH="/Applications/Self Service.app/Contents/Resources/AppIcon.icns"

# Main heading that will be displayed under the image If this variable is left
# blank, the generic banner will appear

BANNER_TITLE="Welcome to Your_Org_Name_Here"

# Paragraph text that will display under the main heading. For a new line,
# use \n If this variable is left blank, the generic message will appear.
# Leave single quotes below as double quotes will break the new lines.

MAIN_TEXT='Thanks for choosing a Mac at Your_Org_Name_Here! We want you to have a few applications and settings configured before you get started with your new Mac. This process should take 10 to 20 minutes to complete. \n \n If you need additional software or help, please visit the Self Service app in your Applications folder or on your Dock.'

# Initial Start Status text that shows as things are firing up
INITAL_START_STATUS="Initial Configuration Starting..."

# Text that will display in the progress bar
INSTALL_COMPLETE_TEXT="Configuration Complete!"

# Complete messaging to the end user can ether be a button at the bottom of the
# app with a modification to the main window text or a dropdown alert box.
# Default value set to false and will use buttons instead of dropdown messages.

COMPLETE_METHOD_DROPDOWN_ALERT=false # Set variable to true or false

# Script designed to automatically logout user to start FileVault process if
# deferred enablement is detected. Text displayed if deferred status is on.
# Option for dropdown alert box

FV_ALERT_TEXT='Your Mac must logout to start the encryption process. You will be asked to enter your password and click OK or Continue a few times. Your Mac will be usable encryption takes place.'

# Options if not using dropdown alert box
FV_COMPLETE_MAIN_TEXT='Your Mac must logout to start the encryption process. You will be asked to enter your password and click OK or Continue a few times. Your Mac will be usable while encryption takes place.'

FV_COMPLETE_BUTTON_TEXT="Logout"

# Text that will display inside the alert once policies have finished
# Option for dropdown alert box
COMPLETE_ALERT_TEXT='Your Mac is now finished with initial setup and configuration. Press Quit to get started!'

# Options if not using dropdown alert box
COMPLETE_MAIN_TEXT='Your Mac is now finished with initial setup and configuration.'

COMPLETE_BUTTON_TEXT="Get Started!"


################################################################################
# PLIST CONFIGURATION
################################################################################
# The menu.depnotify.plist contains more and more things that configure the
# DEPNotify app. You may want to save the file for purposes like verifying EULA
# acceptance or validating other options.

# Plist Save Location
# This wrapper allows variables that are created later to be used but also
# allow for configuration of where the plist is stored
info_plist_wrapper (){

    # Call the get_current_user function
    get_current_user

    DEP_NOTIFY_USER_INPUT_PLIST="/Users/$CURRENT_USER/Library/Preferences/menu.nomad.DEPNotifyUserInput.plist"
}

# Status Text Alignment
# The status text under the progress bar can be configured to be left, right,
# or center
STATUS_TEXT_ALIGN="center"

# Help Button Configuration
# The help button was changed to a popup. Button will appear if title is
# populated.
HELP_BUBBLE_TITLE="Need Help?"
HELP_BUBBLE_BODY='This tool at Your_Org_Name_Here is designed to help \nwith new employee onboarding. \nIf you have issues, please give us a \ncall at 123-456-7890'


################################################################################
# Error Screen Text
################################################################################
# If testing mode is false and configuration files are present, this text will
# appear to the end user and asking them to contact IT. Limited window options
# here as the assumption is that they need to call IT. No continue or exit
# buttons will show for DEP Notify window and it will not show in fullscreen.
# IT staff will need to use Terminal or Activity Monitor to kill DEP Notify.

# Main heading that will be displayed under the image
ERROR_BANNER_TITLE="Uh oh, Something Needs Fixing!"

# Paragraph text that will display under the main heading. For a new line, use
# \n. If this variable is left blank, the generic message will appear. Leave
# single quotes below as double quotes will break the new lines.
ERROR_MAIN_TEXT='We are sorry that you are experiencing this inconvenience with your new Mac. However, we have the nerds to get you back up and running in no time! \n \n Please contact IT right away and we will take a look at your computer ASAP. \n \n Phone: 123-456-7890'

# Error status message that is displayed under the progress bar
ERROR_STATUS="Setup Failed"


################################################################################
# Caffeinate / No Sleep Configuration
################################################################################
# Flag script to keep the computer from sleeping. BE VERY CAREFUL WITH THIS
# FLAG! This flag could expose your data to risk by leaving an unlocked
# computer wide open. Only recommended if you are using fullscreen mode and
# have a logout taking place at the end of configuration (like for FileVault).
# Some folks may use this in workflows where IT staff are the primary people
# setting up the device. The device will be allowed to sleep again once the
# DEPNotify app is quit as caffeinate is looking at DEPNotify's process ID.
NO_SLEEP=false


################################################################################
# Customized Self Service Branding
################################################################################
# Flag for using the custom branding icon from Self Service and Jamf Pro
# This will override the banner image specified above. If you have changed the
# name of Self Service, make sure to modify the Self Service name below.
# Please note, custom branding is downloaded from Jamf Pro after Self Service
# has opened at least one time. The script is designed to wait until the files
# have been downloaded. This could take a few minutes depending on server and
# network resources.
SELF_SERVICE_CUSTOM_BRANDING=false # Set variable to true or false

# If using a name other than Self Service with Custom branding. Change the
# name with the SELF_SERVICE_APP_NAME variable below. Keep .app on the end
SELF_SERVICE_APP_NAME="Self Service.app"


################################################################################
# EULA Variables to Modify
################################################################################
# EULA configuration
EULA_ENABLED=false # Set variable to true or false

# EULA status bar text
EULA_STATUS="Waiting on completion of EULA acceptance"

# EULA button text on the main screen
EULA_BUTTON="Read and Agree to EULA"

# EULA Screen Title
EULA_MAIN_TITLE="Organization End User License Agreement"

# EULA Subtitle
EULA_SUBTITLE='Please agree to the following terms and conditions to start configuration of this Mac'

# Path to the EULA file you would like the user to read and agree to. It is
# best to package this up with Composer or another tool and deliver it to a
# shared area like /Users/Shared/
EULA_FILE_PATH="/Users/Shared/eula.txt"


################################################################################
# Registration Variables to Modify
################################################################################

# Registration window configuration
REGISTRATION_ENABLED=false # Set variable to true or false

# Registration window title
REGISTRATION_TITLE="Mac Registration at Organization"

# Registration status bar text
REGISTRATION_STATUS="Waiting on completion of computer registration"

# Registration window submit or finish button text
REGISTRATION_BUTTON="Register Your Mac"

# The text and pick list sections below will write the following lines out for
# end users. Use the variables below to configure what the sentence says
# Ex: Setting Computer Name to macBook0132
REGISTRATION_BEGIN_WORD="Setting"
REGISTRATION_MIDDLE_WORD="to"

# Registration window can have up to two text fields. Leaving the text display
# variable empty will hide the input box. Display text is to the side of the
# input and placeholder text is the gray text inside the input box.
# Registration window can have up to four dropdown / pick list inputs. Leaving
# the pick display variable empty will hide the dropdown / pick list.

# First Text Field
################################################################################
# Text Field Label
REG_TEXT_LABEL_1="Computer Name"

# Place Holder Text
REG_TEXT_LABEL_1_PLACEHOLDER="macBook0123"

# Optional flag for making the field an optional input for end user
REG_TEXT_LABEL_1_OPTIONAL="false" # Set variable to true or false

# Help Bubble for Input. If title left blank, this will not appear
REG_TEXT_LABEL_1_HELP_TITLE="Computer Name Field"
REG_TEXT_LABEL_1_HELP_TEXT='This field is sets the name of your new Mac to what is in the Computer Name box. This is important for inventory purposes.'

# Logic below was put in this section rather than in core code as folks may
# want to change what the field does. This is a function that gets called
# when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
reg_text_label_1_logic (){
    REG_TEXT_LABEL_1_VALUE=$(defaults \
        read "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_TEXT_LABEL_1")

    if [ "$REG_TEXT_LABEL_1_OPTIONAL" = true ] && \
        [ "$REG_TEXT_LABEL_1_VALUE" = "" ]; then

        echo "Status: $REG_TEXT_LABEL_1 was left empty. Skipping..." >> "$DEP_NOTIFY_LOG"

        echo "$DATE: $REG_TEXT_LABEL_1 was set to optional and was left empty. Skipping..." >> "$DEP_NOTIFY_DEBUG"
        /bin/sleep 5

    else
        echo "Status: $REGISTRATION_BEGIN_WORD $REG_TEXT_LABEL_1 $REGISTRATION_MIDDLE_WORD $REG_TEXT_LABEL_1_VALUE" >> "$DEP_NOTIFY_LOG"

        if [ "$TESTING_MODE" = true ]; then
            /bin/sleep 10

        else
            "$JAMF_BINARY" setComputerName -name "$REG_TEXT_LABEL_1_VALUE"
            /bin/sleep 5
        fi
    fi
}

# Second Text Field
################################################################################

# Text Field Label
REG_TEXT_LABEL_2="Asset Tag"

# Place Holder Text
REG_TEXT_LABEL_2_PLACEHOLDER="81926392"

# Optional flag for making the field an optional input for end user
REG_TEXT_LABEL_2_OPTIONAL="true" # Set variable to true or false

# Help Bubble for Input. If title left blank, this will not appear
REG_TEXT_LABEL_2_HELP_TITLE="Asset Tag Field"
REG_TEXT_LABEL_2_HELP_TEXT='This field is used to give an updated asset tag to our asset management system. If you do not know your asset tag number, please skip this field.'

# Logic below was put in this section rather than in core code as folks may
# want to change what the field does. This is a function that gets called
# when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
reg_text_label_2_logic (){
    REG_TEXT_LABEL_2_VALUE=$(defaults \
        read "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_TEXT_LABEL_2")

    if [ "$REG_TEXT_LABEL_2_OPTIONAL" = true ] && \
        [ "$REG_TEXT_LABEL_2_VALUE" = "" ]; then

        echo "Status: $REG_TEXT_LABEL_2 was left empty. Skipping..." >> "$DEP_NOTIFY_LOG"

        echo "$DATE: $REG_TEXT_LABEL_2 was set to optional and was left empty. Skipping..." >> "$DEP_NOTIFY_DEBUG"
        /bin/sleep 5

    else
        echo "Status: $REGISTRATION_BEGIN_WORD $REG_TEXT_LABEL_2 $REGISTRATION_MIDDLE_WORD $REG_TEXT_LABEL_2_VALUE" >> "$DEP_NOTIFY_LOG"

        if [ "$TESTING_MODE" = true ]; then
            /bin/sleep 10

        else
            "$JAMF_BINARY" recon -assetTag "$REG_TEXT_LABEL_2_VALUE"
        fi
    fi
}

# Popup 1
################################################################################

# Label for the popup
REG_POPUP_LABEL_1="Building"

# Array of options for the user to select
REG_POPUP_LABEL_1_OPTIONS=(
    "Amsterdam"
    "Eau Claire"
    "Minneapolis"
)

# Help Bubble for Input. If title left blank, this will not appear
REG_POPUP_LABEL_1_HELP_TITLE="Building Dropdown Field"
REG_POPUP_LABEL_1_HELP_TEXT='Please choose the appropriate building for where you normally work. This is important for inventory purposes.'

# Logic below was put in this section rather than in core code as folks may
# want to change what the field does. This is a function that gets called
# when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
reg_popup_label_1_logic (){
    REG_POPUP_LABEL_1_VALUE=$(defaults \
        read "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_POPUP_LABEL_1")

    echo "Status: $REGISTRATION_BEGIN_WORD $REG_POPUP_LABEL_1 $REGISTRATION_MIDDLE_WORD $REG_POPUP_LABEL_1_VALUE" >> "$DEP_NOTIFY_LOG"

    if [ "$TESTING_MODE" = true ]; then
        /bin/sleep 10

    else
        "$JAMF_BINARY" recon -building "$REG_POPUP_LABEL_1_VALUE"
    fi
}

# Popup 2
################################################################################
# Label for the popup
REG_POPUP_LABEL_2="Department"

# Array of options for the user to select
REG_POPUP_LABEL_2_OPTIONS=(
    "Customer Onboarding"
    "Professional Services"
    "Sales Engineering"
)

# Help Bubble for Input. If title left blank, this will not appear
REG_POPUP_LABEL_2_HELP_TITLE="Department Dropdown Field"
REG_POPUP_LABEL_2_HELP_TEXT='Please choose the appropriate department for where you normally work. This is important for inventory purposes.'

# Logic below was put in this section rather than in core code as folks may
# want to change what the field does. This is a function that gets called
# when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
reg_popup_label_2_logic (){

    REG_POPUP_LABEL_2_VALUE=$(defaults read \
        "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_POPUP_LABEL_2")

    echo "Status: $REGISTRATION_BEGIN_WORD $REG_POPUP_LABEL_2 $REGISTRATION_MIDDLE_WORD $REG_POPUP_LABEL_2_VALUE" >> "$DEP_NOTIFY_LOG"

    if [ "$TESTING_MODE" = true ]; then
        /bin/sleep 10

    else
        "$JAMF_BINARY" recon -department "$REG_POPUP_LABEL_2_VALUE"
    fi
}

# Popup 3 - Code is here but currently unused
################################################################################

# Label for the popup
REG_POPUP_LABEL_3=""

# Array of options for the user to select
REG_POPUP_LABEL_3_OPTIONS=(
    "Option 1"
    "Option 2"
    "Option 3"
)

# Help Bubble for Input. If title left blank, this will not appear
REG_POPUP_LABEL_3_HELP_TITLE="Dropdown 3 Field"
REG_POPUP_LABEL_3_HELP_TEXT='This dropdown is currently not in use. All code is here ready for you to use. It can also be hidden by removing the contents of the REG_POPUP_LABEL_3 variable.'

# Logic below was put in this section rather than in core code as folks may
# want to change what the field does. This is a function that gets called
# when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
reg_popup_label_3_logic (){

    REG_POPUP_LABEL_3_VALUE=$(defaults read \
        "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_POPUP_LABEL_3")

    echo "Status: $REGISTRATION_BEGIN_WORD $REG_POPUP_LABEL_3 $REGISTRATION_MIDDLE_WORD $REG_POPUP_LABEL_3_VALUE" >> "$DEP_NOTIFY_LOG"

    if [ "$TESTING_MODE" = true ]; then
        /bin/sleep 10

    else
        /bin.sleep 10
    fi
}

# Popup 4 - Code is here but currently unused
################################################################################
# Label for the popup
REG_POPUP_LABEL_4=""

# Array of options for the user to select
REG_POPUP_LABEL_4_OPTIONS=(
    "Option 1"
    "Option 2"
    "Option 3"
)

# Help Bubble for Input. If title left blank, this will not appear
REG_POPUP_LABEL_4_HELP_TITLE="Dropdown 4 Field"
REG_POPUP_LABEL_4_HELP_TEXT='This dropdown is currently not in use. All code is here ready for you to use. It can also be hidden by removing the contents of the REG_POPUP_LABEL_4 variable.'

# Logic below was put in this section rather than in core code as folks may
# want to change what the field does. This is a function that gets called
# when needed later on. BE VERY CAREFUL IN CHANGING THE FUNCTION!
reg_popup_label_4_logic (){

    REG_POPUP_LABEL_4_VALUE=$(defaults read \
        "$DEP_NOTIFY_USER_INPUT_PLIST" "$REG_POPUP_LABEL_4")

    echo "Status: $REGISTRATION_BEGIN_WORD $REG_POPUP_LABEL_4 $REGISTRATION_MIDDLE_WORD $REG_POPUP_LABEL_4_VALUE" >> "$DEP_NOTIFY_LOG"

    if [ "$TESTING_MODE" = true ]; then
        /bin/sleep 10

    else
        /bin/sleep 10
    fi
}


###############################################################################
# FUNCTIONS
###############################################################################

logging () {
    # Logging function

    LOG_FILE="enrollment-$(date +"%Y-%m-%d").log"
    LOG_PATH="/Library/Logs/$LOG_FILE"
    DATE=$(date +"[%b %d, %Y %Z %T INFO]: ")
    printf "$DATE $1\n" >> $LOG_PATH
}


validate_true_false_flags (){
    # Validating true/false flags that are set in the Jamf console for this
    # DEPNotify script.

    if [ "$TESTING_MODE" != true ] && [ "$TESTING_MODE" != false ]; then
        /bin/echo "$DATE: Testing configuration not set properly. Currently set to $TESTING_MODE. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
        logging "DEBUG: Testing configuration not set properly. Currently set to $TESTING_MODE. Please update to true or false."
        exit 1
    fi

    if [ "$FULLSCREEN" != true ] && [ "$FULLSCREEN" != false ]; then
        /bin/echo "$DATE: Fullscreen configuration not set properly. Currently set to $FULLSCREEN. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
        logging "DEBUG: Fullscreen configuration not set properly. Currently set to $FULLSCREEN. Please update to true or false."
        exit 1
    fi

    if [ "$NO_SLEEP" != true ] && [ "$NO_SLEEP" != false ]; then
        /bin/echo "$DATE: Sleep configuration not set properly. Currently set to $NO_SLEEP. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
        logging "DEBUG: Sleep configuration not set properly. Currently set to $NO_SLEEP. Please update to true or false."
        exit 1
    fi

    if [ "$SELF_SERVICE_CUSTOM_BRANDING" != true ] && \
        [ "$SELF_SERVICE_CUSTOM_BRANDING" != false ]; then
        /bin/echo "$DATE: Self Service Custom Branding configuration not set properly. Currently set to $SELF_SERVICE_CUSTOM_BRANDING. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
        logging "DEBUG: Self Service Custom Branding configuration not set properly. Currently set to $SELF_SERVICE_CUSTOM_BRANDING. Please update to true or false."
        exit 1
    fi

    if [ "$COMPLETE_METHOD_DROPDOWN_ALERT" != true ] && \
        [ "$COMPLETE_METHOD_DROPDOWN_ALERT" != false ]; then
        /bin/echo "$DATE: Completion alert method not set properly. Currently set to $COMPLETE_METHOD_DROPDOWN_ALERT. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
        logging "DEBUG: Completion alert method not set properly. Currently set to $COMPLETE_METHOD_DROPDOWN_ALERT. Please update to true or false."
        exit 1
    fi

    if [ "$EULA_ENABLED" != true ] && [ "$EULA_ENABLED" != false ]; then
        /bin/echo "$DATE: EULA configuration not set properly. Currently set to $EULA_ENABLED. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
        logging "DEBUG: EULA configuration not set properly. Currently set to $EULA_ENABLED. Please update to true or false."
        exit 1
    fi

    if [ "$REGISTRATION_ENABLED" != true ] && \
        [ "$REGISTRATION_ENABLED" != false ]; then

        /bin/echo "$DATE: Registration configuration not set properly. Currently set to $REGISTRATION_ENABLED. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
        logging "DEBUG: Registration configuration not set properly. Currently set to $REGISTRATION_ENABLED. Please update to true or false."
        exit 1
    fi

    if [ "$JAMF_CONNECT_ENABLED" != true ] && \
        [ "$JAMF_CONNECT_ENABLED" != false ]; then

        /bin/echo "$DATE: Registration configuration not set properly. Currently set to $JAMF_CONNECT_ENABLED. Please update to true or false." >> "$DEP_NOTIFY_DEBUG"
        logging "DEBUG: Registration configuration not set properly. Currently set to $JAMF_CONNECT_ENABLED. Please update to true or false."
        exit 1
    fi
}


pretty_pause() {
    # Adding nice text and a brief pause for prettiness
    echo "Status: $INITAL_START_STATUS" >> "$DEP_NOTIFY_LOG"
    /bin/sleep 5
}


get_setup_assistant_process () {
    # Wait for Setup Assisant to finish before contiuing
    # Start the setup process after Apple Setup Assistant completes

    PROCESS_NAME="Setup Assistant"

    logging "Checking to see if $PROCESS_NAME is running ..."

    # Initialize setup assistant variable
    SETUP_ASSISTANT_PROCESS=""

    while [[ $SETUP_ASSISTANT_PROCESS != "" ]]; do

        logging "$PROCESS_NAME still running ... PID: $SETUP_ASSISTANT_PROCESS"
        logging "Sleeping 1 second ..."
        /bin/sleep 1
         SETUP_ASSISTANT_PROCESS=$(/usr/bin/pgrep -l "$PROCESS_NAME")

    done

    logging "$PROCESS_NAME finished ... OK"

}


get_finder_process (){
    # Check to see if the Finder is running yet. If it is, continue. Nice for
    # instances where the user is not setting up a username during the Setup
    # Assistant process.

    logging "Checking to see if the Finder process is running ..."
    echo "$DATE Checking to see if the Finder process is running ..."
    FINDER_PROCESS=$(/usr/bin/pgrep -l "Finder" 2> /dev/null)

    RESPONSE=$?

    logging "Finder PID: $FINDER_PROCESS"
    echo "Finder PID: $FINDER_PROCESS"

    while [[ $RESPONSE -ne 0 ]]; do

        logging "Finder PID not found. Assuming device is sitting \
            at the login window ..."
        echo "$DATE: Finder PID not found. Assuming device is sitting \
            at the login window ..."

        /bin/sleep 1

        FINDER_PROCESS=$(/usr/bin/pgrep -l "Finder" 2> /dev/null)
        RESPONSE=$?

        if [[ $FINDER_PROCESS != "" ]]; then
            logging "Finder PID: $FINDER_PROCESS"
            echo "$DATE: Finder PID: $FINDER_PROCESS"
        fi
    done
}


check_for_jamf_connect_login() {
    # check to ensure that jamf connect login is running before moving on
    # to the next step. If Jamf Connect Login is not installed attempt to
    # install it via Jamf Console policy.

    # Counter to keep track of counting
    COUNTER=0

    # Name of custom trigger for Jamf policy
    TRIGGER="jamf-connect-login"

    AUTHCHANGER_BINARY="/usr/local/bin/authchanger"

    logging "Making sure Jamf Connect Login installed ..."

    while [ ! -f "$AUTHCHANGER_BINARY" ]; do

        logging "Jamf Connect Login has not started yet ..."

        if [ ! -f "$AUTHCHANGER_BINARY" ] && [ "$COUNTER" -eq 10 ]; then
            # If Jamf Connect Login not installed, attempt to call the Jamf
            # console policy to install it.

            logging "Waited 10 seconds for Jamf Connect Login ..."
            logging "INSTALLER: Attemting to install Jamf Connect Login via Jamf policy ..."

            "$JAMF_BINARY" policy -event "$TRIGGER" | \
                /usr/bin/sed -e "s/^/$DATE/" | \
                /usr/bin/tee -a "$LOG_PATH" > /dev/null 2>&1

        fi
        logging "Waiting 1 seconds before checking again ..."
        /bin/sleep 1
        # Reset authchanger binary variable so that the while loop catches it.
        AUTHCHANGER_BINARY="/usr/local/bin/authchanger"

        # Increment the counter
        COUNTER=$((COUNTER+1))

    done
    logging "Found Jamf Connect Login ..."
}


check_for_dep_notify_app() {
    # check to ensure that DEPNotify is isntalled before moving on to the next
    # step.
    # If it is not installed attempt to reinstall it using a policy in Jamf Pro.

    # Counter to keep track of Counting
    COUNTER=0

    # Name of custom trigger for Jamf policy
    TRIGGER="install-dep-notify"

    DN_APP="/Applications/Utilities/DEPNotify.app"
    logging "Making sure DEPNotify.app installed ..."

    while [[ ! -d $DN_APP ]]; do

        logging "DEPNotify has not been installed yet ..."

        if [ ! -d "$DN_APP" ] && [ "$COUNTER" -eq 5 ]; then
            # If Jamf Connect Login not installed, attempt to call the Jamf
            # console policy to install it.

            logging "Waited 5 seconds for DEPNotify ..."
            logging "INSTALLER: Attemting to install DEPNotify via Jamf policy ..."

            "$JAMF_BINARY" policy -event "$TRIGGER" | \
                /usr/bin/sed -e "s/^/$DATE/" | \
                /usr/bin/tee -a "$LOG_PATH" > /dev/null 2>&1
        fi

        logging "Waiting 1 seconds before checking again ..."
        /bin/sleep 1
        DN_APP="/Applications/Utilities/DEPNotify.app"
        COUNTER=$((COUNTER+1))

    done
    logging "Found DEPNotify.app ..."
}


is_jamf_enrollment_complete() {
    # Checks the Jamf enrollment status
    # Checks for the Jamf binary. Then, looks for the jamf.log file. Lastly,
    # opens the jamf.log and looks for the string enrollmentComplete.
    # If this is not installed then there is not reason to continue ...

    while [[ ! -f /usr/local/bin/jamf ]]; do
        # Sleep for 2 seconds
        printf "$DATE: Waiting for the jamf binary to install ...\n"
        logging "Enrollment Script: Waiting for the jamf binary to install ..."
        /bin/sleep 2
    done

    logging "Enrollment Script: The Jamf binary is installed."

    until [ -f "/var/log/jamf.log" ]; do
        # If the jamf.log is found wait until we find enrollment complete.
        logging "Enrollment Script: Waiting for jamf log to appear ..."
        /bin/sleep 1
    done

    logging "The jamf.log file has been created."

    # look for the enrollmentComplete string in the Jamf log.
    /usr/bin/grep -q "enrollmentComplete" "/var/log/jamf.log"

    RETURN=$?

    until [ "$RETURN" -eq 0 ]; do
        # Wait for enrollmentComplete to appear in the Jamf log.
        logging "Enrollment Script: Looking for the enrollmentComplete string in the Jamf log."
        /bin/sleep 1
        # look for the enrollmentComplete string in the Jamf log.
        /usr/bin/grep -q "enrollmentComplete" "/var/log/jamf.log"
        RETURN=$?
    done

    logging "Enrollment Script: Jamf enrollment complete."

}


is_dep_notify_enrollment_daemon_loaded() {
    # Check to see if the DEPNotify daemon is loaded and if so unloaded it.
    # If the daemon is already loaded aka the Mac has been enrolled in the past,
    # the deamon will fail to load and therefore will fail to start again.

    logging "Enrollment Script: Checking to see if the DEPNotify LaunchDaemon is loaded."

    DAEMON_STATUS=$(/bin/launchctl list | \
        /usr/bin/grep "dep-notify-enrollment" | \
        /usr/bin/awk '{print $3}')

    if [ -n "$DAEMON_STATUS" ]; then
        # The dameon is running unload it.
        logging "launchctl: Unloading $DAEMON_STATUS before continuing on ..."
        /usr/bin/launchctl unload "/Library/LaunchDaemons/$DAEMON_STATUS.plist"
    fi
}


launch_dep_notify_app (){
    # Opening the DEPNotiy app after initial configuration
    if [ "$FULLSCREEN" = true ]; then
        sudo -u "$CURRENT_USER" \
            open -a "$DEP_NOTIFY_APP" --args -path "$DEP_NOTIFY_LOG" -fullScreen
    elif [ "$FULLSCREEN" = false ]; then
        sudo -u "$CURRENT_USER" \
            open -a "$DEP_NOTIFY_APP" --args -path "$DEP_NOTIFY_LOG"
    fi
}


caffeinate_this() {
    # Using Caffeinate binary to keep the computer awake if enabled
    if [ "$NO_SLEEP" = true ]; then
        printf "$DATE: Caffeinating DEP Notify process. Process ID: $DEP_NOTIFY_PROCESS\n" >> "$DEP_NOTIFY_DEBUG"
        caffeinate -disu -w "$DEP_NOTIFY_PROCESS"&
    fi
}


get_dep_notify_process (){
    # Grabbing the DEP Notify Process ID for use later
    DEP_NOTIFY_PROCESS=$(pgrep -l "DEPNotify" | cut -d " " -f1)

    until [ "$DEP_NOTIFY_PROCESS" != "" ]; do

        /bin/echo "$DATE: Waiting for DEPNotify to start to gather the process ID." >> "$DEP_NOTIFY_DEBUG"
        /bin/sleep 1
        DEP_NOTIFY_PROCESS=$(pgrep -l "DEPNotify" | cut -d " " -f1)

    done

    /bin/echo "$DEP_NOTIFY_PROCESS"

    caffeinate_this "$DEP_NOTIFY_PROCESS"
}


get_current_user() {
    # Return the current user
    CURRENT_USER=$(printf '%s' "show State:/Users/ConsoleUser" | \
        /usr/sbin/scutil | \
        /usr/bin/awk '/Name :/ && ! /loginwindow/ {print $3}')
}


get_current_user_uid() {
    # Check to see if the current console user uid is greater than 501
    # Loop until either the 501 or 502 user is found.

    # Get the current console user again
    get_current_user

    logging "Enrollment Script: Getting current user UID ..."

    CURRENT_USER_UID=$(/usr/bin/dscl . -list /Users UniqueID | \
        /usr/bin/grep "$CURRENT_USER" | \
        /usr/bin/awk '{print $2}' | \
        /usr/bin/sed -e 's/^[ \t]*//')

    logging "Current User: $CURRENT_USER"
    logging "Current User UID: $CURRENT_USER_UID"

    while [[ $CURRENT_USER_UID -lt 501 ]]; do

        logging "Enrollment Script: Current user is not logged in ... WAITING"
        /bin/sleep 1

        # Get the current console user again
        get_current_user

        CURRENT_USER_UID=$(/usr/bin/dscl . -list /Users UniqueID | \
            /usr/bin/grep "$CURRENT_USER" | \
            /usr/bin/awk '{print $2}' | \
            /usr/bin/sed -e 's/^[ \t]*//')

        logging "Enrollment Script: Current User: $CURRENT_USER"
        logging "Enrollment Script: Current User UID: $CURRENT_USER_UID"

        if [[ $CURRENT_USER_UID -lt 501 ]]; then
            logging "Enrollment Script: Current user: $CURRENT_USER with UID ..."
        fi
    done
}


self_service_custom_branding() {
    # If SELF_SERVICE_CUSTOM_BRANDING is set to true. Loading the updated icon
    open -a "/Applications/$SELF_SERVICE_APP_NAME" --hide

    # Loop waiting on the branding image to properly show in the users
    # library
    CUSTOM_BRANDING_PNG="/Users/$CURRENT_USER/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"

    until [ -f "$CUSTOM_BRANDING_PNG" ]; do
        echo "$DATE: Waiting for branding image from Jamf Pro." >> "$DEP_NOTIFY_DEBUG"
        /bin/sleep 1
    done

    # Setting Banner Image for DEP Notify to Self Service Custom Branding
    BANNER_IMAGE_PATH="$CUSTOM_BRANDING_PNG"

    # Setting custom image if specified
    if [ "$BANNER_IMAGE_PATH" != "" ]; then
        echo "Command: Image: $BANNER_IMAGE_PATH" >> "$DEP_NOTIFY_LOG";
    fi

    # Setting custom title if specified
    if [ "$BANNER_TITLE" != "" ]; then
        echo "Command: MainTitle: $BANNER_TITLE" >> "$DEP_NOTIFY_LOG";
    fi

    # Setting custom main text if specified
    if [ "$MAIN_TEXT" != "" ]; then
        echo "Command: MainText: $MAIN_TEXT" >> "$DEP_NOTIFY_LOG";
    fi

    # Closing Self Service
    SELF_SERVICE_PID=$(pgrep -l "$(echo "$SELF_SERVICE_APP_NAME" | \
        /usr/bin/cut -d "." -f1)" | \
        /usr/bin/cut -d " " -f1)

    echo "$DATE: Self Service custom branding icon has been loaded. Killing Self Service PID $SELF_SERVICE_PID." >> "$DEP_NOTIFY_DEBUG"

    kill "$SELF_SERVICE_PID"
}


general_plist_config() {
    # General Plist Configuration

    # Calling function to set the INFO_PLIST_PATH
    info_plist_wrapper

    # The plist information below
    DEP_NOTIFY_CONFIG_PLIST="/Users/$CURRENT_USER/Library/Preferences/menu.nomad.DEPNotify.plist"

    if [ "$TESTING_MODE" = true ] && [ -f "$DEP_NOTIFY_CONFIG_PLIST" ]; then
        # If testing mode is on, this will remove some old configuration files
        rm "$DEP_NOTIFY_CONFIG_PLIST";
    fi

    if [ "$TESTING_MODE" = true ] && [ -f "$DEP_NOTIFY_USER_INPUT_PLIST" ]; then
        rm "$DEP_NOTIFY_USER_INPUT_PLIST";
    fi

    # Setting default path to the plist which stores all the user completed info
    defaults \
        write "$DEP_NOTIFY_CONFIG_PLIST" \
        pathToPlistFile "$DEP_NOTIFY_USER_INPUT_PLIST"

    # Setting status text alignment
    defaults \
        write "$DEP_NOTIFY_CONFIG_PLIST" \
        statusTextAlignment "$STATUS_TEXT_ALIGN"

    if [ "$HELP_BUBBLE_TITLE" != "" ]; then
        # Setting help button

        defaults \
            write "$DEP_NOTIFY_CONFIG_PLIST" \
            helpBubble -array-add "$HELP_BUBBLE_TITLE"

        defaults \
            write "$DEP_NOTIFY_CONFIG_PLIST" \
            helpBubble -array-add "$HELP_BUBBLE_BODY"
    fi

    # Changing Ownership of the plist file
    chown "$CURRENT_USER":staff "$DEP_NOTIFY_CONFIG_PLIST"
    chmod 600 "$DEP_NOTIFY_CONFIG_PLIST"
}


status_bar_gen() {
    # SETTING THE STATUS BAR
    # Counter is for making the determinate look nice. Starts at one and adds
    # more based on EULA, register, or other options.
    ADDITIONAL_OPTIONS_COUNTER=1

    if [ "$EULA_ENABLED" = true ]; then ((ADDITIONAL_OPTIONS_COUNTER++)); fi

    if [ "$REGISTRATION_ENABLED" = true ]; then
        ((ADDITIONAL_OPTIONS_COUNTER++))

        if [ "$REG_TEXT_LABEL_1" != "" ]; then
            ((ADDITIONAL_OPTIONS_COUNTER++));
        fi

        if [ "$REG_TEXT_LABEL_2" != "" ]; then
            ((ADDITIONAL_OPTIONS_COUNTER++));
        fi

        if [ "$REG_POPUP_LABEL_1" != "" ]; then
            ((ADDITIONAL_OPTIONS_COUNTER++));
        fi

        if [ "$REG_POPUP_LABEL_2" != "" ]; then
            ((ADDITIONAL_OPTIONS_COUNTER++));
        fi

        if [ "$REG_POPUP_LABEL_3" != "" ]; then
            ((ADDITIONAL_OPTIONS_COUNTER++));
        fi

        if [ "$REG_POPUP_LABEL_4" != "" ]; then
            ((ADDITIONAL_OPTIONS_COUNTER++));
        fi

    fi

    # Increment status counter for submitting Jamf inventory at end of DEPNotify
    ADDITIONAL_OPTIONS_COUNTER=$((ADDITIONAL_OPTIONS_COUNTER++))

    # Checking policy array and adding the count from the additional options
    # above.
    ARRAY_LENGTH="$((${#POLICY_ARRAY[@]}+ADDITIONAL_OPTIONS_COUNTER))"
    echo "Command: Determinate: $ARRAY_LENGTH" >> "$DEP_NOTIFY_LOG"
}


eula_configuration() {
    # EULA Configuration
    DEP_NOTIFY_EULA_DONE="/var/tmp/com.depnotify.agreement.done"

    # If testing mode is on, this will remove EULA specific configuration
    # files
    if [ "$TESTING_MODE" = true ] && \
        [ -f "$DEP_NOTIFY_EULA_DONE" ]; then

        rm "$DEP_NOTIFY_EULA_DONE"; fi

    # Writing title, subtitle, and EULA txt location to plist
    defaults write "$DEP_NOTIFY_CONFIG_PLIST" \
        EULAMainTitle "$EULA_MAIN_TITLE"
    defaults write "$DEP_NOTIFY_CONFIG_PLIST" EULASubTitle "$EULA_SUBTITLE"
    defaults write "$DEP_NOTIFY_CONFIG_PLIST" pathToEULA "$EULA_FILE_PATH"

    # Setting ownership of EULA file
    chown "$CURRENT_USER:staff" "$EULA_FILE_PATH"
    chmod 444 "$EULA_FILE_PATH"
}


eula_logic  (){
    # EULA Window Display Logic
    /bin/echo "Status: $EULA_STATUS" >> "$DEP_NOTIFY_LOG"
    /bin/echo "Command: ContinueButtonEULA: $EULA_BUTTON" >> "$DEP_NOTIFY_LOG"

    while [ ! -f "$DEP_NOTIFY_EULA_DONE" ]; do
        /bin/echo "$DATE: Waiting for user to accept EULA." >> "$DEP_NOTIFY_DEBUG"
        logging "INFO: Waiting for user to accept EULA."
        /bin/sleep 1
    done
}


configure_registration_plist() {
    # Registration Plist Configuration
    if [ "$REGISTRATION_ENABLED" = true ]; then
        DEP_NOTIFY_REGISTER_DONE="/var/tmp/com.depnotify.registration.done"

        # If testing mode is on, this will remove registration specific
        # configuration files
        if [ "$TESTING_MODE" = true ] && [ -f "$DEP_NOTIFY_REGISTER_DONE" ]; then

            rm "$DEP_NOTIFY_REGISTER_DONE"
        fi

        # Main Window Text Configuration
        "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
            registrationMainTitle "$REGISTRATION_TITLE"
        "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
            registrationButtonLabel "$REGISTRATION_BUTTON"
        "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
            registrationPicturePath "$BANNER_IMAGE_PATH"

        # First Text Box Configuration
        if [ "$REG_TEXT_LABEL_1" != "" ]; then
            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                textField1Label "$REG_TEXT_LABEL_1"
            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                textField1Placeholder "$REG_TEXT_LABEL_1_PLACEHOLDER"
            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                textField1IsOptional "$REG_TEXT_LABEL_1_OPTIONAL"

            # Code for showing the help box if configured
            if [ "$REG_TEXT_LABEL_1_HELP_TITLE" != "" ]; then
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    textField1Bubble -array-add "$REG_TEXT_LABEL_1_HELP_TITLE"
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    textField1Bubble -array-add "$REG_TEXT_LABEL_1_HELP_TEXT"
            fi
        fi

        # Second Text Box Configuration
        if [ "$REG_TEXT_LABEL_2" != "" ]; then

            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                textField2Label "$REG_TEXT_LABEL_2"
            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                textField2Placeholder "$REG_TEXT_LABEL_2_PLACEHOLDER"
            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                textField2IsOptional "$REG_TEXT_LABEL_2_OPTIONAL"

            # Code for showing the help box if configured
            if [ "$REG_TEXT_LABEL_2_HELP_TITLE" != "" ]; then

                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    textField2Bubble -array-add "$REG_TEXT_LABEL_2_HELP_TITLE"
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    textField2Bubble -array-add "$REG_TEXT_LABEL_2_HELP_TEXT"

            fi
        fi

        # Popup 1
        if [ "$REG_POPUP_LABEL_1" != "" ]; then

            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                popupButton1Label "$REG_POPUP_LABEL_1"

            # Code for showing the help box if configured
            if [ "$REG_POPUP_LABEL_1_HELP_TITLE" != "" ]; then

                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupMenu1Bubble -array-add "$REG_POPUP_LABEL_1_HELP_TITLE"
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupMenu1Bubble -array-add "$REG_POPUP_LABEL_1_HELP_TEXT"

            fi

            # Code for adding the items from the array above into the plist
            for REG_POPUP_LABEL_1_OPTION in "${REG_POPUP_LABEL_1_OPTIONS[@]}";
            do
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupButton1Content -array-add "$REG_POPUP_LABEL_1_OPTION"
            done
        fi

        # Popup 2
        if [ "$REG_POPUP_LABEL_2" != "" ]; then

            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                popupButton2Label "$REG_POPUP_LABEL_2"

            # Code for showing the help box if configured
            if [ "$REG_POPUP_LABEL_2_HELP_TITLE" != "" ]; then

                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupMenu2Bubble -array-add "$REG_POPUP_LABEL_2_HELP_TITLE"
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupMenu2Bubble -array-add "$REG_POPUP_LABEL_2_HELP_TEXT"

            fi

            # Code for adding the items from the array above into the plist
            for REG_POPUP_LABEL_2_OPTION in "${REG_POPUP_LABEL_2_OPTIONS[@]}";
            do
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupButton2Content -array-add "$REG_POPUP_LABEL_2_OPTION"
            done
        fi

        # Popup 3
        if [ "$REG_POPUP_LABEL_3" != "" ]; then

            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                popupButton3Label "$REG_POPUP_LABEL_3"

            # Code for showing the help box if configured
            if [ "$REG_POPUP_LABEL_3_HELP_TITLE" != "" ]; then

                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupMenu3Bubble -array-add "$REG_POPUP_LABEL_3_HELP_TITLE"
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupMenu3Bubble -array-add "$REG_POPUP_LABEL_3_HELP_TEXT"

            fi

            # Code for adding the items from the array above into the plist
            for REG_POPUP_LABEL_3_OPTION in "${REG_POPUP_LABEL_3_OPTIONS[@]}";
            do
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupButton3Content -array-add "$REG_POPUP_LABEL_3_OPTION"
            done
        fi

        # Popup 4
        if [ "$REG_POPUP_LABEL_4" != "" ]; then

            "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                popupButton4Label "$REG_POPUP_LABEL_4"

            # Code for showing the help box if configured
            if [ "$REG_POPUP_LABEL_4_HELP_TITLE" != "" ]; then

                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupMenu4Bubble -array-add "$REG_POPUP_LABEL_4_HELP_TITLE"
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupMenu4Bubble -array-add "$REG_POPUP_LABEL_4_HELP_TEXT"

            fi
            # Code for adding the items from the array above into the plist
            for REG_POPUP_LABEL_4_OPTION in "${REG_POPUP_LABEL_4_OPTIONS[@]}";
            do
                "$DEFAULTS" write "$DEP_NOTIFY_CONFIG_PLIST" \
                    popupButton4Content -array-add "$REG_POPUP_LABEL_4_OPTION"
            done
        fi
    fi
}


registration_window_display_logic (){

    configure_registration_plist

    # Registration Window Display Logic
    echo "Status: $REGISTRATION_STATUS" >> "$DEP_NOTIFY_LOG"
    echo "Command: ContinueButtonRegister: $REGISTRATION_BUTTON" >> "$DEP_NOTIFY_LOG"

    while [ ! -f "$DEP_NOTIFY_REGISTER_DONE" ]; do
        echo "$DATE: Waiting for user to complete registration." >> "$DEP_NOTIFY_DEBUG"
        /bin/sleep 1
    done

    # Running Logic For Each Registration Box
    if [ "$REG_TEXT_LABEL_1" != "" ]; then reg_text_label_1_logic; fi
    if [ "$REG_TEXT_LABEL_2" != "" ]; then reg_text_label_2_logic; fi
    if [ "$REG_POPUP_LABEL_1" != "" ]; then reg_popup_label_1_logic; fi
    if [ "$REG_POPUP_LABEL_2" != "" ]; then reg_popup_label_2_logic; fi
    if [ "$REG_POPUP_LABEL_3" != "" ]; then reg_popup_label_3_logic; fi
    if [ "$REG_POPUP_LABEL_4" != "" ]; then reg_popup_label_4_logic; fi
}


install_policies() {
    # Install policies by looping through the policy array defined above.
    #
    # If a policy is installing an application the function will first check to
    # see if the app is already installed on the system and skip that policy
    # if the app is found.

    logging "Enrollment Script: Preparing to install Jamf application policies."

    for policy in "${POLICY_ARRAY[@]}"; do
        # Loop through the policy array and install each policy

        # psuedo local variables
        policy_status=$(/bin/echo "$policy" | cut -d ',' -f1)
        policy_name=$(/bin/echo "$policy" | cut -d ',' -f2)

        if [[ $TESTING_MODE = true ]]; then
            logging "Enrollment Script: Test mode enabled ... INFO"
            sleep 10

        elif [[ $TESTING_MODE = false ]]; then
            # Install the given policy
            logging "Enrollment Script: Jamf: calling $policy_name policy."
            echo "Status: $policy_status" >> "$DEP_NOTIFY_LOG"
            "$JAMF_BINARY" policy \
                -event "$policy_name" | \
        		/usr/bin/sed -e "s/^/$DATE/" | \
        		/usr/bin/tee -a "$LOG_PATH" > /dev/null 2>&1
        fi
    done
}


set_computer_name () {
    # Set the computer name

    # Store device serial number
    SERIAL_NUMBER=$(/usr/sbin/system_profiler SPHardwareDataType | \
            /usr/bin/awk '/Serial\ Number\ \(system\)/ {print $NF}')

    logging "Enrollment Script: Setting computer name to: $SERIAL_NUMBER"

    # Set device name using scutil
    /usr/sbin/scutil --set ComputerName "${SERIAL_NUMBER}"
    /usr/sbin/scutil --set LocalHostName "${SERIAL_NUMBER}"
    /usr/sbin/scutil --set HostName "${SERIAL_NUMBER}"

    # Set device name using jamf binary to make sure of the correct name
    "$JAMF_BINARY" setComputerName -useSerialNumber

}


update_username_in_jamf_cloud() {
    # Ensure that the username field is populated under the device inventory
    # record.
    logging "Enrollment Script: Calling Jamf policy to update username inventory record."
    "$JAMF_BINARY" policy -event update-username
}


enable_location_services() {
    # Enable location services
    logging "Enrollment Script: locationd: Enableing Location services ..."
    sudo -u _locationd /usr/bin/defaults \
        -currentHost write com.apple.locationd LocationServicesEnabled -int 1
}


lock_login_keychain() {
    # Lock Keychain while Sleep
    logging "Enrollment Script: Keychain: Lock keychain while device is sleeping."
    sudo security set-keychain-settings -l
}


filevault_configuration() {
    # Check to see if FileVault Deferred enablement is active

    /bin/echo "Status: Checking FileVault" >> "$DEP_NOTIFY_LOG"

    FV_DEFERRED_STATUS=$($FDESETUP_BINARY status | \
        /usr/bin/grep "Deferred" | \
        /usr/bin/cut -d ' ' -f6)

    # Logic to log user out if FileVault is detected. Otherwise, app will close.
    if [ "$FV_DEFERRED_STATUS" = "active" ] && [ "$TESTING_MODE" = true ]; then
        if [ "$COMPLETE_METHOD_DROPDOWN_ALERT" = true ]; then
            /bin/echo "Command: Quit: This is typically where your FV_LOGOUT_TEXT would be displayed. However, TESTING_MODE is set to true and FileVault deferred status is on." >> "$DEP_NOTIFY_LOG"
        else
            /bin/echo "Command: MainText: TESTING_MODE is set to true and FileVault deferred status is on. Button effect is quit instead of logout. \n \n $FV_COMPLETE_MAIN_TEXT" >> "$DEP_NOTIFY_LOG"
            /bin/echo "Command: ContinueButton: Test $FV_COMPLETE_BUTTON_TEXT" >> "$DEP_NOTIFY_LOG"
        fi

    elif [ "$FV_DEFERRED_STATUS" = "active" ] && \
        [ "$TESTING_MODE" = false ]; then

        if [ "$COMPLETE_METHOD_DROPDOWN_ALERT" = true ]; then
        /bin/echo "Command: Logout: $FV_ALERT_TEXT" >> "$DEP_NOTIFY_LOG"

        else
            /bin/echo "Command: MainText: $FV_COMPLETE_MAIN_TEXT" >> "$DEP_NOTIFY_LOG"
            /bin/echo "Command: ContinueButtonLogout: $FV_COMPLETE_BUTTON_TEXT" >> "$DEP_NOTIFY_LOG"
        fi

    else
      if [ "$COMPLETE_METHOD_DROPDOWN_ALERT" = true ]; then
        /bin/echo "Command: Quit: $COMPLETE_ALERT_TEXT" >> "$DEP_NOTIFY_LOG"
      else
        /bin/echo "Command: MainText: $COMPLETE_MAIN_TEXT" >> "$DEP_NOTIFY_LOG"
        /bin/echo "Command: ContinueButton: $COMPLETE_BUTTON_TEXT" >> "$DEP_NOTIFY_LOG"
      fi
    fi
}


checkin_to_jamf() {
    # Force the Mac to checkin with Jamf and submit its enventory.
    logging "Enrollment Script: Submitting device inventory to Jamf ..."
    /bin/echo "Status: Submitting device inventory to Jamf" >> "$DEP_NOTIFY_LOG"
    "$JAMF_BINARY" recon
}


dep_notify_cleanup() {
    # Call DEPNotify cleanup policy
    #
    # Calls a policy containing a script to remove depnotify components that
    # are left behind by the enrollment proces.
    # This script can be found in the Jamf-DEPNotify repository.

    logging "Enrollment Script: jamf: Calling policy: dep-notify-cleanup"
    "$JAMF_BINARY" policy -event dep-notify-cleanup
}


create_stub_file() {
    # Create the a stub file
    #
    # Set the name of the stub file to your liking or pass the name of a stub
    # to this function as the $1 builtin.
    #
    # While the stub file does not exist, create it.
    # Force device checkin to jamf to initiate extension attribute
    # If the stub file exists, move the device to the "Enrollment Complete"
    # SmartGroup so that the wifi profile payload will come down.
    # Otherwise, continue checking for the stub file

    if [ "$1" != "" ]; then
        STUB_FILE_NAME="$1"
        logging "Using function arg"
    else
        STUB_FILE_NAME=".enrollment_complete.txt"
    fi

    stub_file_path="/Users/Shared/$STUB_FILE_NAME"

    while [ ! -f "$stub_file_path" ]; do
        # Create STUB file
        logging "Laying down $STUB_FILE_NAME stub file"
        /usr/bin/touch "$stub_file_path"

        # Set the stub location
        stub_file_path="/Users/Shared/$STUB_FILE_NAME"

        if [ -f "$stub_file_path" ]; then
            logging "$STUB_FILE_NAME Stub file found!!!"

        else
            logging "Still looking for $STUB_FILE_NAME stub file ..."
            /bin/sleep 1
            /usr/bin/touch "$stub_file_path"

        fi

    done

}


reboot_me() {
    # Rebooting to complete provisioning
    "$JAMF_BINARY" policy -event enrollment-complete-reboot | \
        /usr/bin/sed -e "s/^/$DATE/" | \
        /usr/bin/tee -a "$LOG_PATH" > /dev/null 2>&1
}


###############################################################################
###############################################################################
####   MAING SCRIPT: DO NOT EDIT BELOW THIS LINE
###############################################################################
###############################################################################


# Binaries
DEFAULTS="/usr/bin/defaults"
FDESETUP_BINARY="/usr/bin/fdesetup"
JAMF_BINARY="/usr/local/bin/jamf"

# Log files
LOG_FILE="enrollment-$(date +"%Y-%m-%d").log"
LOG_PATH="/Library/Logs/$LOG_FILE"
DATE=$(date +"[%b %d, %Y %Z %T INFO]")
DEP_NOTIFY_APP="/Applications/Utilities/DEPNotify.app"
DEP_NOTIFY_LOG="/var/tmp/depnotify.log"
DEP_NOTIFY_DEBUG="/var/tmp/depnotifyDebug.log"
DEP_NOTIFY_DONE="/var/tmp/com.depnotify.provisioning.done"


# Pulling from Policy parameters to allow true/false flags to be set. More
# info can be found on
# https://www.jamf.com/jamf-nation/articles/146/script-parameters
# These will override what is specified in the script above.

# Testing Mode
if [ "$4" != "" ]; then TESTING_MODE="$4"; fi
# Fullscreen Mode
if [ "$5" != "" ]; then FULLSCREEN="$5"; fi
# No Sleep / Caffeinate Mode
if [ "$6" != "" ]; then NO_SLEEP="$6"; fi
# Self Service Custom Branding
if [ "$7" != "" ]; then SELF_SERVICE_CUSTOM_BRANDING="$7"; fi
# Complete method dropdown or main screen
if [ "$8" != "" ]; then COMPLETE_METHOD_DROPDOWN_ALERT="$8"; fi
# EULA Mode
if [ "$9" != "" ]; then EULA_ENABLED="$9"; fi
# Registration Mode
if [ "${10}" != "" ]; then REGISTRATION_ENABLED="${10}"; fi
# Jamf Connect Enabled
if [ "${11}" != "" ]; then JAMF_CONNECT_ENABLED="${11}"; fi


#
# Standard Testing Mode Enhancements
#

if [ "$TESTING_MODE" = true ]; then

    # Removing old config file if present (Testing Mode Only)
    if [ -f "$DEP_NOTIFY_LOG" ]; then rm "$DEP_NOTIFY_LOG"; fi
    if [ -f "$DEP_NOTIFY_DONE" ]; then rm "$DEP_NOTIFY_DONE"; fi
    if [ -f "$DEP_NOTIFY_DEBUG" ]; then rm "$DEP_NOTIFY_DEBUG"; fi

    # Setting Quit Key set to command + control + x (Testing Mode Only)
    echo "Command: QuitKey: x" >> "$DEP_NOTIFY_LOG"
fi


main() {
    # Main function

    logging ""
    logging "--- BEGIN DEVICE ENROLLMENT LOG ---"
    logging ""
    logging "Jamf DEPNotify Enrollment Script Version ${VERSION}"
    logging ""

    # Adding Check and Warning if Testing Mode is off and BOM files exist
    if [[ ( -f "$DEP_NOTIFY_LOG" || \
        -f "$DEP_NOTIFY_DONE" ) && \
        "$TESTING_MODE" = false ]]; then

        echo "$DATE: TESTING_MODE set to false but config files were found in /var/tmp. Letting user know and exiting." >> "$DEP_NOTIFY_DEBUG"

        mv "$DEP_NOTIFY_LOG" "/var/tmp/depnotify_old.log"

        echo "Command: MainTitle: $ERROR_BANNER_TITLE" >> "$DEP_NOTIFY_LOG"
        echo "Command: MainText: $ERROR_MAIN_TEXT" >> "$DEP_NOTIFY_LOG"
        echo "Status: $ERROR_STATUS" >> "$DEP_NOTIFY_LOG"

        sudo -u "$CURRENT_USER" \
            open -a "$DEP_NOTIFY_APP" --args -path "$DEP_NOTIFY_LOG"

        /bin/sleep 5

        exit 1
    fi


    validate_true_false_flags
    get_setup_assistant_process


    if [ "$JAMF_CONNECT_ENABLED" = true ]; then
        # We are using Jamf Connect
        # If this is not enabled then there is no reason to run the function.
        check_jamf_connect_login
    else
        printf "Enrollment Script: Not using Jamf Connect ...\n"
        logging "Enrollment Script: Not using Jamf Connect ..."
    fi

    is_jamf_enrollment_complete
    check_for_dep_notify_app
    get_finder_process
    get_current_user_uid

    if [ "$SELF_SERVICE_CUSTOM_BRANDING" = true ]; then
        # If this is not enabled then there is no reason to run the function.
        self_service_custom_branding
    fi

    general_plist_config
    is_dep_notify_enrollment_daemon_loaded
    launch_dep_notify_app
    get_dep_notify_process


    # Adding an alert prompt to let admins know that the script is in testing
    # mode
    if [ "$TESTING_MODE" = true ]; then
        /bin/echo "Command: Alert: DEP Notify is in TESTING_MODE. Script will not run Policies or other commands that make change to this computer."  >> "$DEP_NOTIFY_LOG"
    fi


    pretty_pause
    status_bar_gen

    if [ "$EULA_ENABLED" = true ]; then
        # If this is not enabled then there is no reason to run the function.
        eula_configuration
        eula_logic
    fi

    if [ "$REGISTRATION_ENABLED" = true ]; then
        # If this is not enabled then there is no reason to run the function.
        registration_window_display_logic
    fi

    install_policies
    set_computer_name

    if [ "$UPDATE_USERNAME_INVENTORY_RECORD" = true ]; then
        # If this is not enabled then there is no reason to run the function.
        update_username_in_jamf_cloud
    fi

    enable_location_services
    lock_login_keychain
    create_stub_file ".enrollment_complete.txt"
    checkin_to_jamf
    filevault_configuration


    # Nice completion text
    echo "Status: $INSTALL_COMPLETE_TEXT" >> "$DEP_NOTIFY_LOG"


    dep_notify_cleanup


    logging ""
    logging "--- END DEVICE ENROLLMENT LOG ---"
    logging ""

}

# Call the main funcion
main

exit 0
