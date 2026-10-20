local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local work_commands = require('aineo.claude.work_commands')

local T = MiniTest.new_set()

T['a command that makes work'] = MiniTest.new_set({
  parametrize = {
    {
      'git worktree add -b feature/x ../wt',
      { kind = 'worktree', path = '../wt', branch = 'feature/x' },
    },
    {
      'git worktree add -B feature/x ../wt origin/dev',
      { kind = 'worktree', path = '../wt', branch = 'feature/x', start = 'origin/dev' },
    },
    { 'git worktree add ../wt', { kind = 'worktree', path = '../wt' } },
    {
      'git worktree add --detach ../wt abc1234',
      { kind = 'worktree', path = '../wt', start = 'abc1234' },
    },
    {
      'git worktree add -q -f -b x -- /tmp/wt main',
      { kind = 'worktree', path = '/tmp/wt', branch = 'x', start = 'main' },
    },
    {
      'git -C /projects/alpha worktree add -b x /tmp/wt',
      { kind = 'worktree', path = '/tmp/wt', branch = 'x', directory = '/projects/alpha' },
    },
    {
      [[git worktree add -b 'my branch' "../my wt"]],
      { kind = 'worktree', path = '../my wt', branch = 'my branch' },
    },
    { 'git checkout -b feature/y', { kind = 'branch', branch = 'feature/y' } },
    {
      'git checkout -q -B feature/y origin/dev',
      { kind = 'branch', branch = 'feature/y', start = 'origin/dev' },
    },
    { 'git switch -c feature/z', { kind = 'branch', branch = 'feature/z' } },
    { 'git switch -C feature/z main', { kind = 'branch', branch = 'feature/z', start = 'main' } },
    { 'git switch --create feature/z', { kind = 'branch', branch = 'feature/z' } },
    { 'git switch --force-create feature/z', { kind = 'branch', branch = 'feature/z' } },
    { 'git branch feature/w', { kind = 'branch', branch = 'feature/w' } },
    { 'git branch feature/w HEAD~2', { kind = 'branch', branch = 'feature/w', start = 'HEAD~2' } },
    {
      '  git   -C ../alpha   branch   w  ',
      { kind = 'branch', branch = 'w', directory = '../alpha' },
    },
  },
})

T['a command that makes work']['is read as the work it makes'] = function(command, work)
  eq(work_commands.work_of(command), work)
end

T['a command that is not plain'] = MiniTest.new_set({
  parametrize = {
    { 'cd /projects/alpha && git checkout -b x' },
    { 'git checkout -b x && git push' },
    { 'git worktree add -b x ../wt; rm -rf ../wt' },
    { 'git worktree add -b x $HOME/wt' },
    { 'git worktree add -b x ~/wt' },
    { 'git branch "a$(id)"' },
    { 'git branch `id`' },
    { 'git branch a\\ b' },
    { 'git branch x | cat' },
    { 'git branch x > out' },
    { 'git branch x\ngit branch y' },
    { "git branch 'unterminated" },
    { 'GIT_DIR=/x git branch y' },
    { 'git -c core.x=y branch z' },
    { 'git --git-dir=/x branch z' },
    { 'git -C' },
    { 'git' },
    { 'gitk' },
    { 'git checkout main' },
    { 'git checkout -b' },
    { 'git checkout -b x --track origin/x' },
    { 'git checkout -b -x' },
    { 'git switch main' },
    { 'git switch --create=z' },
    { 'git branch' },
    { 'git branch -d x' },
    { 'git branch --list' },
    { 'git branch a b c' },
    { 'git worktree list' },
    { 'git worktree add' },
    { 'git worktree add -b' },
    { 'git worktree add --lock -b x ../wt' },
    { 'git worktree add -b x ../wt main extra' },
    { 'git status' },
  },
})

T['a command that is not plain']['is read as no work'] = function(command)
  eq(work_commands.work_of(command), nil)
end

return T
