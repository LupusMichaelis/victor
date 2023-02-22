#!/bin/bash

set -euo pipefail
shopt -s lastpipe

declare -r GITHUB_API_BASEURI="https://api.github.com"
declare -r SHAMEFUL_BRANCH=master

export $(grep -v '^#' .env | xargs)

main()
{
	check-default-branch

	check-git-template-dir
	git-template "$GIT_TEMPLATE_DIR"

	check-git-home-dir
	git-local-scrub "$GIT_HOME_DIR"

	check-dependencies
	check-user
	check-token
	github-master-no-more
}

die()
{
	echo >&2 "$1"
	exit "$2"
}

check-non-empty-env()
{
	if (( $# < 1 ))
	then
		die 'No environment name provided to check' 3
	fi

	if (( 2 == $# ))
	then
		local -r help=": $2"
	else
		local -r help=''
	fi


	local -r name="$1"
	local error_message=''
	if [[ ! -v "$name" || -z "${!name}" ]]
	then
		printf 'Please define variable '\''%b'\'' in .env%b' "$name" "$help" |
			read error_message
		die "$error_message" 2
	fi
}

check-git-template-dir()
{
	check-non-empty-env GIT_TEMPLATE_DIR 'template git dir'

	GIT_TEMPLATE_DIR="$(eval echo "$( eval echo "$GIT_TEMPLATE_DIR" )")"
	[ -d "$GIT_TEMPLATE_DIR" ] \
		|| die "Variable GIT_TEMPLATE_DIR '$GIT_TEMPLATE_DIR' is not a directory" 2

}
check-git-home-dir()
{
	check-non-empty-env GIT_HOME_DIR 'local directory hosting your Git repository'
	GIT_HOME_DIR="$(eval echo "$( eval echo "$GIT_HOME_DIR" )")"
	[ -d "$GIT_HOME_DIR" ] \
		|| die "Variable GIT_HOME_DIR '$GIT_HOME_DIR' is not a directory" 2
}

check-dependencies()
{
	for exe in jq curl
	do
		type $exe >/dev/null 2>&1 \
			|| die "Please install '$exe'." 1
	done
}

check-default-branch()
{
	check-non-empty-env DEFAULT_BRANCH 'new main branch name (main, trunk)'
}

check-user()
{
	check-non-empty-env GITHUB_USER 'Github username'
}

check-token()
{
	check-non-empty-env GITHUB_TOKEN 'Github user token (visit https://github.com/settings/tokens)'
}

github-call()
{
	local -r path="${1#/}"
	shift

	declare -ar curl_args=(
		-k
		-u "$GITHUB_USER:$GITHUB_TOKEN"
		-H 'Accept: application/vnd.github.v3+json'
		-H 'Content-type: application/json'
		"$GITHUB_API_BASEURI/$path"
		"$@"
	)

	curl ${curl_args[@]} ||
		die "Error on API call" 4
}

github-master-no-more()
{
	local -r repos="$(github-call "/users/$GITHUB_USER/repos" | jq -r '.[] | .name')"
	local repo

	for repo in $repos
	do
		local refs="$(github-call \
			"/repos/$GITHUB_USER/$repo/git/refs")"

		local sha=$(echo $refs | jq -r '.[]|select(.ref=="refs/heads/'$SHAMEFUL_BRANCH'")|.object.sha')

		github-call \
			"/repos/$GITHUB_USER/$repo/git/refs" \
			-X POST \
			-d '{"ref": "refs/heads/'$DEFAULT_BRANCH'", "sha": "'$sha'"}'

		github-call \
			"/repos/$GITHUB_USER/$repo" \
			-X PATCH \
			-d '{ "default_branch": "'$DEFAULT_BRANCH'"}'

		github-call "/repos/$GITHUB_USER/$repo/git/refs/heads/$SHAMEFUL_BRANCH" -X DELETE
	done
}

git-template()
{
	local -r target="$1"
	shift

	git init --bare $target
	echo ref: "refs/heads/$DEFAULT_BRANCH" > "$target/HEAD"
	git config --global init.templateDir "$target"
}

git-local-scrub()
{
	local path="$1"
	shift

	for repo in $(find "$path" -mindepth 1 -maxdepth 1 -type d)
	do
		cd "$repo"
		if ! git switch "$DEFAULT_BRANCH"
		then
			git checkout -b "$DEFAULT_BRANCH"
			git branch -D "$SHAMEFUL_BRANCH"
		fi
		cd -
	done
}

main
