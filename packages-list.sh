#!/bin/sh

readme_file="README.RFRemix"
temp="/tmp/github-repos"
result_file="${temp}/result.html"
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

function head_readme_file {
    echo "<html>" >> $result_file
    echo "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />" >> $result_file
    echo "<body>" >> $result_file
    echo "<table border='1' cols='5'>" >> $result_file
    echo "<thead align=\"center\">" >> $result_file
    echo "<tr>" >> $result_file
    echo "<td><b>Название</b></td>" >> $result_file
    echo "<td><b>Описание</b></td>" >> $result_file
    echo "<td><b>Мейнтейнер</b></td>" >> $result_file
    echo "<td><b>Репозиторий</b></td>" >> $result_file
    echo "<td><b>Почему не в апстриме</b></td>" >> $result_file
    echo "<td><b>Комментарий</b></td>" >> $result_file
    echo "</tr>" >> $result_file
    echo "</thead>" >> $result_file
}

function foot_readme_file {
    echo "</table>" >> $result_file
    echo "</html>" >> $result_file
}

function read_readme_file {
    dir=$1
    result_file=$2

    echo "<tr>" >> $result_file

    echo "<td>${dir}</td>" >> $result_file
    while read line; do
        str=`echo "${line}" | awk 'BEGIN { FS = ":" } ; {$1="";print $0}' | cut -c 2-`
        echo "<td>${str}</td>" >> $result_file
    done < $readme_file

    echo "</tr>" >> $result_file
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
	    if [ "$operation" == "write" ]; then
            field="ssh_url"
	    fi
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
    pushd $temp
else
    mkdir -p $temp || exit 1
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


head_readme_file
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
foot_readme_file
    
popd
echo "Done"
