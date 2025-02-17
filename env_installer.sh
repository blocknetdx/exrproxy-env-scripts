#!/bin/bash

location="${HOME}/exrproxy-env"
pyversion=3.9.14

############################################################
# Check Package Manager                                    #
############################################################
APT_CMD=$(which apt)
APT_GET_CMD=$(which apt-get)
if grep -q "/" <<< "$APT_CMD"; then
	PKM="apt"
elif grep -q "/" <<< "$APT_GET_CMD"; then
	PKM="apt-get"
else
	printf "%s\n\033[91;1mCan't use this script without apt or apt-get\n\033[0m"
	exit 1;
fi

############################################################
# Install OS dependencies                                  #
############################################################
function installosdependencies() {
	sudo $PKM update -y
  sudo $PKM install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
}

############################################################
# Check Docker Engine                                      #
############################################################
function checkdocker() {
  dockerversion="20.10.13"

  if ! command -v docker &> /dev/null; then
    printf "%s\n\033[91;1mDocker not found\033[0m\n"
    printf "%s\n\033[92;1mInstalling Docker\033[0m\n"
    installdocker
  else
    docker_version=$(docker --version | awk '{print $3}' | sed 's/,$//')
    
    if [ "$(printf '%s\n' "$dockerversion" "$docker_version" | sort -V | head -n1)" = "$dockerversion" ]; then
      printf "%s\n\033[92;1mDocker found and version is greater than or equal to ${dockerversion}\033[0m\n"
    else
      printf "%s\n\033[91;1mLess than ${dockerversion}. You have to upgrade.\033[0m\n"
    fi
  fi
}

############################################################
# Install Docker                                           #
############################################################
function installdocker() {
    sudo $PKM update -y
    sudo $PKM upgrade -y

	# Add Docker's official GPG key:
	sudo apt-get install ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	echo \
	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	sudo apt-get update

    # Install Docker Engine
    # sudo $PKM update -y
    sudo $PKM install -y docker-ce docker-ce-cli containerd.io

    # Verify Docker installation
    sudo docker --version
}


############################################################
# Check Docker Compose                                     #
############################################################
function checkdockercompose() {
	composeversion="2.3.3"
	COMPOSE=$(which docker-compose)
	if grep -q "/" <<< "$COMPOSE"; then
		printf "%s\n\033[92;1mDocker Compose found\033[0m"
		COMPOSE_VERSION=$(docker-compose --version | awk -F'v' '{print $3}')
		if [ "$(printf '%s\n' "$composeversion" "$COMPOSE_VERSION" | sort --version-sort | head -n1)" = "$composeversion" ]; then 
			printf "%s\n\033[92;1mGreater than or equal to ${composeversion}\033[0m\n"
		else
			printf "%s\n\033[91;1mLess than ${composeversion}. You have to upgrade\033[0m\n"
		fi
	else
		printf "%s\n\033[91;1mDocker Compose not found\033[0m\n"
		printf "%s\n\033[92;1mInstalling Docker Compose\033[0m\n"
		installdockercompose
	fi
}


############################################################
# Install Docker Compose                                   #
############################################################
function installdockercompose() {
	# Find newest version
	VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
	DESTINATION=/usr/bin/docker-compose
	# Download to DESTINATION
	sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
	# Add permissions 
	sudo chmod 755 $DESTINATION
}


############################################################
# Uninstall Docker                                         #
############################################################
# function uninstalldocker() {
# 	DOCKER=$(which docker)
# 	if grep -q "/" <<< "$DOCKER"; then
# 		printf "%s\033[93;1mDocker found\033[0m"
# 		printf "%s\n\033[93;1mThis script will stop all running docker containers\033[0m"
# 		printf "%s\n\033[93;1mthen remove the currently installed version of docker.\033[0m"
# 		printf "%s\n\033[93;1mDo you wish to continue? Press \033[92;1my \033[93;1mor \033[92;1mn\033[0m"
# 		echo ""
# 		read -p "" -n 1 -r
# 		if [[ $REPLY =~ ^[Yy]$ ]]; then
# 			for i in $(docker ps -q); do 
# 				printf "%s\033[93;1mStopping container $i\033[0m"
# 				docker stop $i; 
# 			done
# 			docker system prune -f && docker volume prune -f && docker network prune -f
# 		else
# 			printf "%s\n\033[91;1mStopping this script\n\033[0m"
# 			exit 1;
# 		fi
# 	fi
#   sudo systemctl stop docker.service
#   sudo systemctl stop docker.socket
#   sudo systemctl stop containerd
#   sudo $PKM purge -y containerd.io docker-engine docker docker.io docker-ce docker-ce-cli docker-ce-rootless-extras docker-scan-plugin docker-compose
#   sudo $PKM autoremove -y --purge -y containerd.io docker-engine docker docker.io docker-ce docker-ce-cli docker-ce-rootless-extras docker-scan-plugin docker-compose
#   sudo rm -rf /var/lib/docker /etc/docker
#   sudo rm /etc/apparmor.d/docker
#   sudo rm -rf /var/run/docker.sock
#   sudo rm /usr/bin/docker-compose
#   sudo rm /usr/local/bin/docker-compose
#   sudo rm /usr/share/keyrings/docker-archive-keyring.gpg
# }



############################################################
# Docker as non-root user                                  #
############################################################
function dockergroup() {
	sudo groupadd docker
	sudo usermod -aG docker $USER
	sudo systemctl restart docker
}

############################################################
# Check if script as already installed                     #
############################################################
function checkinstallran() {
	toreturn=0
	if [ ! -r ~/.pyenv/ ]
	then
	    printf "%s\n\033[93;1m${HOME}/.pyenv dir not found\n\033[0m"
	    printf "%s\n\033[93;1mInstalling pyenv, etc...\n\033[0m"
	    toreturn=1
	fi
	if [ ! -r ~/exrproxy-env/ ]
	then
	    printf "%s\n\033[93;1m${HOME}/exrproxy-env/ dir not found\n\033[0m"
	    printf "%s\n\033[93;1mCloning exrproxy-env repo, etc...\n\033[0m"
	    toreturn=1
	fi
	if ! groups | grep -qw "docker";
	then
	    printf "%s\n\033[93;1mUser $USER is not a member of docker group\n\033[0m"
	    printf "%s\n\033[93;1mAdding user $USER to docker group, etc...\n\033[0m"
	    toreturn=1
	fi
	return $toreturn
}

############################################################
# Install python                                           #
############################################################
function installpyenv() {
  # Ensure git is installed
  if [ ! -r ~/.pyenv/ ]
  then
      git clone https://github.com/pyenv/pyenv.git ~/.pyenv
      git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
      echo '
  # pyenv
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  if command -v pyenv 1>/dev/null 2>&1; then
      eval "$(pyenv init -)"
      eval "$(pyenv virtualenv-init -)" # Enable auto-activation of virtualenvs
  fi' >> ~/.bashrc
      source ~/.bashrc
      
      # Directly set pyenv environment variables in the script
      export PYENV_ROOT="$HOME/.pyenv"
      export PATH="$PYENV_ROOT/bin:$PATH"

      # Initialize pyenv and pyenv-virtualenv within the script
      echo "Initializing pyenv..."
      if command -v pyenv 1>/dev/null 2>&1; then
        eval "$(pyenv init -)"
        eval "$(pyenv virtualenv-init -)"
      else
        echo "pyenv not found after installation!"
        exit 1
      fi

  fi
}


############################################################
# Set python pyenv local version                           #
############################################################
function setpyenvlocal() {
    # Assumes $PWD is $location
    pyenv install -s $pyversion
    pyenv local $pyversion

    # Check if the python version matches the desired one
    installed_version=$(python --version 2>&1 | awk '{print $2}')

    if [[ "$installed_version" != "$pyversion" ]]; then
        echo "Error: Expected Python version $pyversion, but got $installed_version."
        exit 1  # Exit the script if the version doesn't match
    else
        echo "Python version $installed_version is correctly set."
    fi
}

############################################################
# Install python requirements                              #
############################################################
function installpythonrequirements() {
	# Assumes $PWD is $location
	pip install -r requirements.txt
}

############################################################
# Install git                                              #
############################################################
function installgit() {
	sudo $PKM update -y
	sudo $PKM install -y git
}

############################################################
# Clone repo                                               #
############################################################
function clonerepo() {
	if [ -d "$location" ]; then
		printf "%s\n\033[93;1m $location found. Updating...\n\033[0m"
		git -C $location stash
		git -C $location pull
	else
		printf "%s\n\033[93;1m $location not found. Cloning...\n\033[0m"
		git clone https://github.com/blocknetdx/exrproxy-env.git $location
		# git clone -b dev-autobuilder-pom https://github.com/blocknetdx/exrproxy-env.git $location
	fi
}

############################################################
# Logout user                                              #
############################################################
logout_user() {
  echo -e "\033[92;1mEnv install completed, You will now be logged out.\033[0m"

  # print a countdown to inform user
  for i in {5..1}; do
    echo -e "\033[92;1mLogging off in $i seconds...\033[0m"
    sleep 1
  done

  # Cleanly log out the user if running in an interactive shell
  if [ -n "$PS1" ]; then
    logout
  else
    # If not an interactive shell, force kill the parent process (may be risky!)
    kill -9 $PPID
  fi
}

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   printf "%s\n\033[94;1mEnterprise \033[96;1mXRouter \033[94;1mProxy Environment\033[0m"
   printf "%s\n\033[92;1mPowered by Blocknet.co"
   printf '%s\n'
   printf "%s\n\033[97;1moptions:"
   printf "%s\n\033[93;1m-h | --help       \033[97;1mPrint this Help."
   printf "%s\n\033[93;1m--install         \033[97;1mIf pyenv not installed, exrproxy-env repo not cloned, or user $USER not in docker group:"
   printf "%s\n\033[93;1m                  \033[97;1mInstalls OS dependencies, git, docker,"
   printf "%s\n\033[93;1m                  \033[97;1mdocker-compose, python3-pip,"
   printf "%s\n\033[93;1m                  \033[97;1mpython3, pyenv, adds user $USER to docker group"
   printf "%s\n\033[93;1m                  \033[97;1mand clones exrproxy-env repo."
   printf "%s\n\033[93;1m--install         \033[97;1mIf pyenv installed, exrproxy-env repo cloned, and user $USER in docker group:"
   printf "%s\n\033[93;1m                  \033[97;1mSets local pyenv python version"
   printf "%s\n\033[93;1m                  \033[97;1mand installs python dependencies."
   printf '%s\n'
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
VALID_ARGS=$(getopt -o h --long help,install -- "$@")
if [[ $? -ne 0 ]]; then
	exit 1;
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    -h | --help)
      Help
      shift
      ;;
    -i | --install)
      # Installing OS dependencies
      printf "%s\n\033[92;1mInstalling OS dependencies\n\033[0m"
      installosdependencies
      
      # Installing git
      printf "%s\n\033[92;1mInstalling git\n\033[0m"
      installgit
      
      # Install docker & docker-compose
      printf "%s\n\033[92;1mInstalling docker & docker-compose\n\033[0m"
      checkdocker
      checkdockercompose
      
      # Adding $USER to docker group
      printf "%s\n\033[92;1mAdding $USER to docker group\n\033[0m"
      dockergroup
      
      # Clone repo
      printf "%s\n\033[92;1mCloning exrproxy-env repo\n\033[0m"
      clonerepo
      

      printf "%s\n\033[92;1mInstalling pyenv\n\033[0m"
      installpyenv

      cd "$location" || exit
      
      # Set python pyenv local version
      printf "%s\n\033[92;1mSetting local python version in $location to $pyversion \n\033[0m"
      setpyenvlocal
      
      # Install python requirements
      printf "%s\n\033[92;1mInstalling python3 requirements\n\033[0m"
      installpythonrequirements

      # Logout
      logout_user
 
      shift
      ;;
    
    --)
      shift
      break
      ;;
    
    *)
      echo "Unknown option: $1"
      shift
      ;;
  esac
done
