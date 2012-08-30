#!/bin/sh

readme_file="README.RFRemix"
temp="/tmp/github-repos"
result_file="${temp}/result.txt"
nolist_file="${temp}/nofile-list.txt"

github_username=""
github_password=""
with_auth=0
github_api_url="https://api.github.com/orgs/RussianFedora/repos"
list_file="${temp}/list.txt"

function read_readme_file {
    dir=$1
    echo "${dir}:" >> $result_file
    while read line; do
        echo -e "\t${line}" >> $result_file
    done < $readme_file
}

if [ -d $temp ]; then
    pushd $temp
else
    mkdir -p $temp || exit 1
    pushd $temp
fi

# Download all repository
rm -rf list.txt
if [ $with_auth -lt 1 ]; then
    curl -i ${github_api_url} > $list_file
else
    curl -u "${github_username}:${github_password}" -i ${github_api_url} > $list_file
fi
repos=`cat list.txt | grep git_url | awk '{print $2}' | sed 's|["\,]||g' | sort`
for repo in $repos; do
    git clone $repo
done

# Remove result_file
if [ -f $result_file ]; then
    rm -rf $result_file
fi

# Check README.RFRemix
dirs=`find . -maxdepth 1 -type d`
for dir in $dirs; do
    if [ "$dir" == "." ]; then
        continue
    fi
    dir_name=`echo $dir | cut -c 3-`
    pushd $dir

    found="NO"
    if [ -f $readme_file ]; then
        read_readme_file $dir_name
        found="YES"
    else
        branches=`git branch -a | grep -vE "HEAD|\*|bz" | sed 's|remotes/origin/||g'`
        for branch in $branches; do
            git checkout $branch > /dev/null 2>&1
            if [ -f $readme_file ]; then
                read_readme_file $dir_name
                found="YES"
                break
            fi
        done
    fi

    if [ "$found" == "NO" ]; then
        echo "${dir_name}" >> $nolist_file
    fi
    popd
done
    
popd
