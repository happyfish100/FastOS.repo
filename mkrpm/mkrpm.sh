#!/bin/bash

[ "x$1" == 'x' ] && echo "$0 <package-path> [module]" && exit 1

package=$(echo ${1%/} | awk -F / '{print $NF}')
module_name=''
overwrite=0
if [ -n "$2" ]; then
  if [ "$2" == "--force" ]; then
    overwrite=1
  else
    module_name=$2
    if [ -n "$3" ] && [ "$3" == "--force" ]; then
      overwrite=1
    fi
  fi
fi

if [ -z $module_name ]; then
  if [ -f $1/$package.spec ]; then
    mv_spec=0
    spec_path=$(ls $(pwd)/$1/$package.spec)
  elif [ -f $1/$package.spec.in ]; then
    mv_spec=1
    spec_path=$(ls $(pwd)/$1/$package.spec.in)
  elif [ -f $1/*.spec ]; then
    mv_spec=0
    spec_path=$(ls $(pwd)/$1/*.spec)
  elif [ -f $1/*.spec.in ]; then
    mv_spec=1
    spec_path=$(ls $(pwd)/$1/*.spec.in)
  fi
else
  if [ -f $1/$module_name.spec ]; then
    mv_spec=0
    spec_path=$(ls $(pwd)/$1/$module_name.spec)
  elif [ -f $1/$module_name.spec.in ]; then
    mv_spec=1
    spec_path=$(ls $(pwd)/$1/$module_name.spec.in)
  else
    echo "spec file for moudle $module_name not exist"
    exit 2
  fi
fi

if [ $? -ne 0 ]; then
   exit
fi

uname=$(uname)
if [ $uname != 'Linux' ]; then
  echo "Only support Linux"
  exit
fi

osname=$(cat /etc/os-release | grep -w NAME | awk -F '=' '{print $2;}' | \
        awk -F '"' '{if (NF==3) {print $2} else {print $1}}' | awk '{print $1}')
if [ $osname != 'CentOS' ]; then
  echo "Only support CentOS"
  exit
fi
os_major_version=$(cat /etc/system-release | awk '{print $4}' | awk -F '.' '{print $1}')

shell_path=$(dirname $0)

if [ ${shell_path:0:1} != '/' ]; then
  shell_path=$(pwd)/$shell_path
fi

export LANG=en_US.UTF-8
pack_path=$(dirname $spec_path)
subdir1=$(echo $1 | awk -F '/' '{print $1;}')
subdir2=$(echo $1 | awk -F '/' '{print $2;}')
if [ -n "$subdir2" ]; then
  work_path=~/mkrpm/$subdir1
else
  work_path=~/mkrpm
fi
mkdir -p $work_path

pack=$(basename $spec_path | sed 's/.spec$//g' | sed 's/.spec.in$//g')
cd $pack_path
if [ -f make.sh ]; then
   ./make.sh clean >/dev/null 2>&1
fi

git pull
if [ $? -ne 0 ]; then
   exit
fi

commit_version=$(git log | head -n 1 | awk '{print $2;}')

ver=$(cat $spec_path | grep ' [0-9]*\.[0-9]*\.[0-9]*$' | awk '{ print $NF; }' | head -n 1)
cd $work_path && rm -rf $pack-$ver &&  cp -r $pack_path $pack-$ver || exit 1
if [ $mv_spec -eq 1 ]; then
  mv $pack-$ver/$pack.spec.in $pack-$ver/$pack.spec || exit 1
fi

sed -i "s/\\\$COMMIT_VERSION/$commit_version/" $pack-$ver/$pack.spec
tar -czf $pack-$ver.tar.gz $pack-$ver && rpmbuild -ta $pack-$ver.tar.gz || exit 1
cd $work_path && rm -rf $pack-$ver $pack-$ver.tar.gz

arch="el$os_major_version"
hardware=$(uname -r | awk -F '.' '{print $NF;}')

if [ "$arch" = 'el7' ]; then
  dist="$arch.centos.$hardware"
else
  dist="$arch.$hardware"
fi

rpmdir=~/rpmbuild/RPMS/x86_64/
if [ ! -d $rpmdir ]; then
  mkdir -p $rpmdir
fi

passwd=$(cat /etc/mkrpm/passwd)
fdebug=$pack-debuginfo-$ver-1.$dist.rpm
dsize=`ls -l $rpmdir/$fdebug | awk '{print $5}'`
[ $? -eq 0 ] && [ $dsize -gt 10000 ] && files=$fdebug && $shell_path/addsign.exp $rpmdir/$fdebug $passwd

for rpm in `cat $spec_path | grep '%define' | grep -v Version | awk '{print $3}'` `cat $spec_path | grep Name: | grep -v '\}' | awk -F: '{print $2}'`
do
file=$rpm-$ver-1.$dist.rpm
if [ -f $rpmdir/$file ] && [ $file != $fdebug ]; then
  $shell_path/addsign.exp $rpmdir/$file $passwd
  files="$files $file"
fi

done

cd $rpmdir
filewithversion=$rpm-$ver-1.$dist
stableexist=$(yum list $filewithversion 2>/dev/null | fgrep $rpm | fgrep $ver-1.$arch)
if [ $overwrite -eq 1 ] || [ -z "$stableexist" ]; then
  IP=$(ifconfig -a | grep -w inet | grep -v 127.0.0.1 | awk '{print $2}')
  REPO_PATH="/usr/html/yumrepo/$arch/x86_64"
  if [ "$IP" = '172.17.7.215' ]; then
    cp $files $REPO_PATH/ && touch $REPO_PATH/.createrepo.flag
  else
    scp $files root@39.106.8.170:$REPO_PATH/ && ssh root@39.106.8.170 touch $REPO_PATH/.createrepo.flag
  fi
else
  echo "Error: Please increace your version first"
fi
