#!/bin/sh

readme_file="README.RFRemix"
temp="/tmp/github-repos"
result_file="${temp}/result.txt"
nolist_file="${temp}/nofile-list.txt"
excludes_file="${temp}/excludes.txt"

github_username=""
github_password=""

operation="read"
if [ "1$1" == "1templates" ]; then
    operation="write"
fi

if [ "1$github_username" == "1" ] && [ "1github_password" == "1" ]; then
    if [ "$operation" == "write" ]; then
        echo "Create templates withou authentication is not support"
        exit 1
    fi
fi

function read_readme_file {
    dir=$1
    result_file=$2
    echo "${dir}:" >> $result_file
    while read line; do
        echo -e "\t${line}" >> $result_file
    done < $readme_file
}

function remove_repos {
    dirs=`find . -maxdepth 1 -type d`
    for dir in $dirs; do
        if [ "$dir" == "." ]; then
            continue
        fi
        rm -rf $dir
    done
}

function get_repos {
    list_file="./list.txt"
    github_api_url="https://api.github.com/orgs/RussianFedora/repos"
    github_username=$1
    github_password=$2

    with_auth=0
    field="git_url"
    if [ "1$github_username" != "1" ] && [ "1github_password" != "1" ]; then
        with_auth=1
        field="ssh_url"
    fi

    rm -rf list.txt
    remove_repos
    if [ $with_auth -lt 1 ]; then
        curl -i ${github_api_url} > $list_file
    else
        curl -u "${github_username}:${github_password}" -i ${github_api_url} > $list_file
    fi
    repos=`cat list.txt | grep $field | awk '{print $2}' | sed 's|["\,]||g' | sort`
    for repo in $repos; do
        git clone $repo
    done
}

function create_template {
    name=$1

    git checkout f17/fixes || git checkout master
    echo "Название:                   ${name}" >> $readme_file
    echo "Мейнтейнер:                 неизвестен" >> $readme_file
    echo "Репозиторий:                неизвестен" >> $readme_file
    echo "Почему не в апстриме:       неизвестно" >> $readme_file
    echo "Комментарий:                файл автоматически сформирован обработкой, исправьте его!" >> $readme_file 
    git add $readme_file
    git commit -a -m "Added README.RFRemix automatically"
    git push
}    

if [ -d $temp ]; then
    cp excludes.txt ${temp}/
    pushd $temp
else
    mkdir -p $temp || exit 1
    cp excludes.txt ${temp}/
    pushd $temp
fi

# Download all repository
get_repos $github_username $github_password

# Remove result_file
if [ -f $result_file ]; then
    rm -rf $result_file
fi
if [ -f $nolist_file ]; then
    rm -rf $nolist_file
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
        if [ "$operation" == "read" ]; then
            read_readme_file $dir_name $result_file
        fi
        found="YES"
    else
        branches=`git branch -a | grep -vE "HEAD|\*|bz" | sed 's|remotes/origin/||g'`
        for branch in $branches; do
            git checkout $branch > /dev/null 2>&1
            if [ -f $readme_file ]; then
                if [ "$operation" == "read" ]; then
                    read_readme_file $dir_name $result_file
                fi
                found="YES"
                break
            fi
        done
    fi

    if [ "$found" == "NO" ]; then
        if [ "$operation" == "read" ]; then
            echo "${dir_name}" >> $nolist_file
        elif [ "$operation" == "write" ]; then
            do_create="NO"
            while read line; do
                if [ "$line" == "$dir_name" ]; then
                    continue
                fi
                do_create="YES"

            done < $excludes_file
            if [ "$do_create" == "YES" ]; then
                create_template $dir_name
            fi
        fi
        
    fi
    popd
done
    
popd
echo "Done"
