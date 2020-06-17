# A script to replace master branches

On the wake of the BLM movement, I discovered that GitHub's master get its
[roots from a Master/Slave](https://mail.gnome.org/archives/desktop-devel-list/2019-May/msg00066.html)
metaphor. In a effort to remove such indignity, here is a script to clean:
  - local repositories
  - remote GitHub repositories

As the git init default main branch is hardcoded, and until corrected versions reach our
workstations, it also provide a Git repository template without the master branch.

# Usage

```
export GIT_TEMPLATE_DIR=~/repositories/template.git
export GIT_HOME_DIR=~/workshop
export GITHUB_USER=VictorSchoelcher
export GITHUB_TOKEN=123

./aboli.sh
```
You will need to create a
[token](visit https://github.com/settings/tokens)
to clean your GitHub's repos.

# Improvement

This is a quick and dirty script, please submit improvements as they arise in your
workflow.

# Naming

I named the project `victor` to reference
[Victor Schroelcher](https://en.wikipedia.org/wiki/Victor_Sch%C5%93lcher), who've been
instrumental in slavery abolision in France and colonies.
