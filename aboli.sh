#!/bin/bash

GITHUB_API_BASEURI="https://api.github.com"
SHAMEFUL_BRANCH=master

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

check-git-template-dir()
{
	[[ -z "$GIT_TEMPLATE_DIR" || ! -d "$GIT_TEMPLATE_DIR" ]] \
		&& die "Please define variable GIT_TEMPLATE_DIR to the path where the template Git repos will be hosted" 2
}
check-git-home-dir()
{
	[[ -z "$GIT_HOME_DIR" || ! -d "$GIT_HOME_DIR" ]] \
		&& die "Please define variable GIT_HOME_DIR to your local directory hosting your Git repos" 2
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
	[[ -z "$DEFAULT_BRANCH" ]] \
		&& die "Please define variable DEFAULT_BRANCH containing new main branch name (main, trunk)" 2
}

check-user()
{
	[[ -z "$GITHUB_USER" ]] \
		&& die "Please define variable GITHUB_USER which corresponds to your GitHub username" 2
}

check-token()
{
	[[ -z "$GITHUB_TOKEN" ]] \
		&& die "Please define variable GITHUB_TOKEN (visit https://github.com/settings/tokens)" 2
}

github-call()
{
	local path=$1
	shift

	curl \
		-k \
		-u $GITHUB_USER:$GITHUB_TOKEN \
		-H 'Accept: application/vnd.github.v3+json' \
		-H 'Content-type: application/json' \
		"$GITHUB_API_BASEURI$path" \
		"$@" || die "Error on API call" 4
}

github-master-no-more()
{
	local repos=$(github-call /users/LupusMichaelis/repos | jq -r '.[] | .name')

	for repo in $repos
	do
		local refs=$(github-call \
			"/repos/$GITHUB_USER/$repo/git/refs")

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
	local target="$1"
	shift

	git init --bare $target
	echo ref: refs/heads/$DEFAULT_BRANCH > $target/HEAD
	git config --global init.templateDir $target
}

git-local-scrub()
{
	local path=$1
	shift

	for repo in $(ls $path)
	do
		cd $path/$repo
		git checkout -b trunk
		git branch -D master
		cd -
	done
}

main
