use Test::More 'no_plan';
use strict;
use warnings;

use FindBin;
use utf8;
use lib "$FindBin::Bin/../mojo/lib";
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../extlib/lib/perl5";
use File::Path 'rmtree';
use Encode qw/encode decode/;

use Test::Mojo;

# Test DB
my $db_file = $ENV{GITPREP_DB_FILE} = "$FindBin::Bin/user.db";

# Test Repository home
my $rep_home = $ENV{GITPREP_REP_HOME} = "$FindBin::Bin/user";

$ENV{GITPREP_NO_MYCONFIG} = 1;


use Gitprep;

# For perl 5.8
{
  no warnings 'redefine';
  sub note { print STDERR "# $_[0]\n" unless $ENV{HARNESS_ACTIVE} }
}

note 'Start page';
{
  unlink $db_file;

  my $app = Gitprep->new;
  my $t = Test::Mojo->new($app);
  $t->ua->max_redirects(3);
  
  # Redirect to _start page
  $t->get_ok('/');
  $t->content_like(qr/Create Admin User/);

  # Page access
  $t->get_ok('/_start');
  $t->content_like(qr/Create Admin User/);
  
  # Password is empty
  $t->post_ok('/_start?op=create', form => {password => ''});
  $t->content_like(qr/Password is empty/);
  
  # Password contains invalid character
  $t->post_ok('/_start?op=create', form => {password => "\t"});
  $t->content_like(qr/Password contains invalid character/);

  # Password contains invalid character
  $t->post_ok('/_start?op=create', form => {password => 'a' x 21});
  $t->content_like(qr/Password is too long/);

  # Two password don't match
  $t->post_ok('/_start?op=create', form => {password => 'a', password2 => 'b'});
  $t->content_like(qr/Two password/);
  
  # Create admin user
  $t->post_ok('/_start?op=create', form => {password => 'a', password2 => 'a'});
  $t->content_like(qr/Login page/);

  # Admin user already exists(Redirect to top page)
  $t->post_ok('/_start?op=create', form => {password => 'a', password2 => 'a'});
  $t->content_like(qr/Users/);
}

note 'Admin pages';
{
  unlink $db_file;

  my $app = Gitprep->new;
  my $t = Test::Mojo->new($app);
  $t->ua->max_redirects(3);

  # Create admin user
  $t->post_ok('/_start?op=create', form => {password => 'a', password2 => 'a'});
  $t->content_like(qr/Login page/);
  
  # Page access
  $t->get_ok('/_login');
  $t->content_like(qr/Login page/);
  
  # Login fail
  $t->post_ok('/_login?op=login', form => {id => 'admin', password => 'b'});
  $t->content_like(qr/User name or password is wrong/);

  # Login success
  $t->post_ok('/_login?op=login', form => {id => 'admin', password => 'a'});
  $t->content_like(qr/Admin/);
  
  note 'Admin page';
  {
    $t->post_ok('/_admin');
    $t->content_like(qr/Admin/);
  }
  
  note 'Admin User page';
  {
    $t->get_ok('/_admin/users');
    $t->content_like(qr/Admin Users/);
  }

  note 'Create User page';
  {
    # Page access
    $t->get_ok('/_admin/user/create');
    $t->content_like(qr/Create User/);
    
    # User name is empty
    $t->post_ok('/_admin/user/create?op=create', form => {id => ''});
    $t->content_like(qr/User name is empty/);

    # User name contain invalid character
    $t->post_ok('/_admin/user/create?op=create', form => {id => '&'});
    $t->content_like(qr/User name contain invalid character/);

    # User name is too long
    $t->post_ok('/_admin/user/create?op=create', form => {id => 'a' x 21});
    $t->content_like(qr/User name is too long/);

    # Password is empty
    $t->post_ok('/_admin/user/create?op=create', form => {id => 'a', password => ''});
    $t->content_like(qr/Password is empty/);

    # Password contain invalid character
    $t->post_ok('/_admin/user/create?op=create', form => {id => 'a', password => "\t"});
    $t->content_like(qr/Password contain invalid character/);

    # Password contain invalid character
    $t->post_ok('/_admin/user/create?op=create', form => {id => 'a', password => 'a' x 21});
    $t->content_like(qr/Password is too long/);

    # Password contain invalid character
    $t->post_ok('/_admin/user/create?op=create', form => {id => 'a', password => 'a', password2 => 'b'});
    $t->content_like(qr/Two password/);
    
    # Create user
    $t->post_ok('/_admin/user/create?op=create', form => {id => 'kimoto', password => 'a', password2 => 'a'});
    $t->content_like(qr/Success.*created/);
  }
    
  note 'Admin Users page';
  $t->get_ok('/_admin/users');
  $t->content_like(qr/Admin Users/);
  $t->content_like(qr/kimoto/);
  
  note 'Reset password page';
  {
    # Page access
    $t->get_ok('/reset-password?user=kimoto');
    $t->content_like(qr/Reset Password/);
    $t->content_like(qr/kimoto/);
    
    # Password is empty
    $t->post_ok('/reset-password?user=kimoto&op=reset', form => {password => ''});
    $t->content_like(qr/Password is empty/);

    # Password contains invalid character
    $t->post_ok('/reset-password?user=kimoto&op=reset', form => {password => "\t"});
    $t->content_like(qr/Password contains invalid character/);

    # Password is too long
    $t->post_ok('/reset-password?user=kimoto&op=reset', form => {password => 'a' x 21});
    $t->content_like(qr/Password is too long/);
    
    # Two password don't match
    $t->post_ok('/reset-password?user=kimoto&op=reset', form => {password => 'a', password2 => 'b'});
    $t->content_like(qr/Two password/);

    # Reset password
    $t->post_ok('/reset-password?user=kimoto&op=reset', form => {password => 'a', password2 => 'a'});
    $t->content_like(qr/Success.*changed/);
  }

  note 'Delete user';
  {
    # Create user
    $t->post_ok('/_admin/user/create?op=create', form => {id => 'kimoto-tmp', password => 'a', password2 => 'a'});
    $t->content_like(qr/kimoto-tmp/);
    $t->get_ok('/_admin/users');
    $t->content_like(qr/kimoto-tmp/);

    # User not exists
    $t->post_ok('/_admin/users?op=delete', form => {user => 'kimoto-notting'});
    $t->content_like(qr/Internal/);

    # User not exists
    $t->post_ok('/_admin/users?op=delete', form => {user => 'kimoto-tmp'});
    $t->content_like(qr/User.*deleted/);
    $t->get_ok('/_admin/users');
    $t->content_unlike(qr/kimoto-tmp/);
  }
  
  note 'logout';
  $t->get_ok('/_logout');
  $t->get_ok('/_admin');
  $t->content_like(qr/Users/);
}

note 'Reset password';
{
  unlink $db_file;

  my $app = Gitprep->new;
  my $t = Test::Mojo->new($app);
  $t->ua->max_redirects(3);

  # Create admin user
  $t->post_ok('/_start?op=create', form => {password => 'a', password2 => 'a'});
  $t->content_like(qr/Login page/);;

  # Not loing user can't access
  $t->get_ok('/reset-password');
  $t->content_like(qr/Users/);

  # Cnahge password(reset_password conf on)
  $app->config->{admin}{reset_password} = 1;
  $t->get_ok('/reset-password');
  $t->content_like(qr/Reset Password/);
  $t->post_ok('/reset-password?op=reset', form => {password => 'b', password2 => 'b'});
  $t->content_like(qr/Success.*changed/);
  $app->config->{admin}{reset_password} = 0;

  # Login success
  $t->post_ok('/_login?op=login', form => {id => 'admin', password => 'b'});
  $t->content_like(qr/Admin/);
  
  # Create user
  $t->post_ok('/_admin/user/create?op=create', form => {id => 'kimoto1', password => 'a', password2 => 'a'});
  $t->content_like(qr/kimoto1/);
  $t->post_ok('/_admin/user/create?op=create', form => {id => 'kimoto2', password => 'a', password2 => 'a'});
  $t->content_like(qr/kimoto2/);
  
  # Logout
  $t->get_ok('/_logout');
  
  # Login as kimoto
  $t->post_ok('/_login?op=login', form => {id => 'kimoto1', password => 'a'});
  $t->get_ok('/')->content_like(qr/kimoto1/);

  # Don't change other user password
  $t->get_ok('/reset-password?user=kimoto2');
  $t->content_like(qr/Users/);
  $t->post_ok('/reset-password?user=kimoto2&op=reset', form => {password => 'b', password2 => 'b'});
  $t->content_like(qr/Users/);

  # Reset password
  $t->get_ok('/reset-password?user=kimoto1');
  $t->content_like(qr/Reset Password/);
  $t->post_ok('/reset-password?user=kimoto1&op=reset', form => {password => 'b', password2 => 'b'});
  
  # Login as kimoto
  $t->get_ok('/_logout');
  $t->post_ok('/_login?op=login', form => {id => 'kimoto1', password => 'b'});
  $t->get_ok('/')->content_like(qr/kimoto1/);
}

note 'Profile';
{
  unlink $db_file;
  rmtree $rep_home;

  my $app = Gitprep->new;
  my $t = Test::Mojo->new($app);
  $t->ua->max_redirects(3);

  # Create admin user
  $t->post_ok('/_start?op=create', form => {password => 'a', password2 => 'a'});
  $t->content_like(qr/Login page/);

  # Login as admin
  $t->post_ok('/_login?op=login', form => {id => 'admin', password => 'a'});

  # Create user
  $t->post_ok('/_admin/user/create?op=create', form => {id => 'kimoto1', password => 'a', password2 => 'a'});
  $t->content_like(qr/kimoto1/);
  $t->post_ok('/_admin/user/create?op=create', form => {id => 'kimoto2', password => 'a', password2 => 'a'});
  $t->content_like(qr/kimoto2/);
  
  # Login as kimoto1
  $t->post_ok('/_login?op=login', form => {id => 'kimoto1', password => 'a'});

  # Profile
  $t->get_ok('/kimoto1/_settings');
  $t->content_like(qr/Profile/);
  
  # Other user can't access
  $t->get_ok('/kimoto2/_settings');
  $t->content_like(qr/Users/);
  
  note 'Create repository';
  {
    # Create repository page
    $t->get_ok('/_new');
    $t->content_like(qr/Create repository/);
    
    # Not logined user can't access
    $t->get_ok('/_logout');
    $t->get_ok('/_new');
    $t->content_like(qr/Users/);
    $t->post_ok('/_login?op=login', form => {id => 'kimoto1', password => 'a'});
    
    # Create repository
    $t->post_ok('/_new?op=create', form => {project => 't1', description => 'Hello'});
    $t->content_like(qr/Create a new repository on the command line/);
    $t->content_like(qr/t1\.git/);
    $t->content_like(qr/Hello/);
    ok(-f "$rep_home/kimoto1/t1.git/git-daemon-export-ok");
    ok(-f "$rep_home/kimoto1/t1.git/hooks/post-update");

    # Create repository(with readme)
    $t->post_ok('/_new?op=create', form => {project => 't2', description => 'Hello', readme => 1});
    $t->content_like(qr/first commit/);
    $t->content_like(qr/t2\.git/);
    $t->content_like(qr/README\.md/);
    $t->content_like(qr/kimoto1\@localhost/);
    $t->content_like(qr/Hello/);

    # Settings page(don't has README)
    $t->get_ok('/kimoto1/t1/settings');
    $t->content_like(qr/Settings/);

    # Settings page(has README)
    $t->get_ok('/kimoto1/t2/settings');
    $t->content_like(qr/Settings/);
  }
  
  note 'Project settings';
  {
    note 'Rename project';
    {
      # Empty
      $t->post_ok('/kimoto1/t2/settings?op=rename-project', form => {});
      $t->content_like(qr/Repository name is empty/);
      
      # Invalid character
      $t->post_ok('/kimoto1/t2/settings?op=rename-project', form => {'to-project' => '&'});
      $t->content_like(qr/Repository name contains invalid charactor/);
      
      # Rename project
      $t->post_ok('/kimoto1/t2/settings?op=rename-project', form => {'to-project' => 't3'});
      $t->content_like(qr/Repository name is renamed to t3/);
      $t->post_ok('/kimoto1/t3/settings?op=rename-project', form => {'to-project' => 't2'});
      $t->content_like(qr/Repository name is renamed to t2/);
    }
    
    note 'Change description';
    {
      # Change description(t1)
      $t->post_ok("/kimoto1/t1/settings?op=change-description", form => {description => 'あああ'});
      $t->content_like(qr/Description is saved/);
      $t->content_like(qr/あああ/);

      # Change description(t2)
      $t->post_ok("/kimoto1/t2/settings?op=change-description", form => {description => 'いいい'});
      $t->content_like(qr/Description is saved/);
      $t->content_like(qr/いいい/);
    }
    
    note 'Change default branch';
    {
      # Default branch default
      $t->get_ok('/kimoto1/t1/settings');
      $t->content_like(qr/master/);
      
      # Change default branch
      my $cmd = "git --git-dir=$rep_home/kimoto1/t2.git branch b1";
      system($cmd) == 0 or die "Can't execute git branch";
      $t->get_ok('/kimoto1/t2/settings');
      $t->content_like(qr/b1/);
      $t->post_ok("/kimoto1/t2/settings?op=default-branch", form => {'default-branch' => 'b1'});
      $t->content_like(qr/Default branch is changed to b1/);
    }
    
    note 'Delete project';
    {
      $t->post_ok('/kimoto1/t1/settings?op=delete-project');
      $t->content_like(qr/Repository t1 is deleted/);
      $t->get_ok('/kimoto1');
      $t->content_unlike(qr/t1/);
    }
  }
}

note 'fork';
{
  my $app = Gitprep->new;
  my $t = Test::Mojo->new($app);
  $t->ua->max_redirects(3);
  
  # Don't logind
  $t->get_ok("/kimoto1/t2/fork");
  $t->content_like(qr/Users/);

  # Login as kimoto2
  $t->post_ok('/_login?op=login', form => {id => 'kimoto2', password => 'a'});
  
  # Fork kimoto1/t2
  $t->get_ok("/kimoto1/t2/fork");
  $t->content_like(qr#Repository is forked from /kimoto1/t2#);
  $t->content_like(qr/いいい/);
  
  # Fork kimoto1/t2 again
  $t->get_ok("/kimoto1/t2/fork");
  $t->content_like(qr/forked from/);
  $t->content_like(qr#kimoto1/t2#);
  $t->content_unlike(qr/Repository is forked from/);
}

note 'Network';
{
  my $app = Gitprep->new;
  my $t = Test::Mojo->new($app);
  $t->ua->max_redirects(3);

  $t->get_ok("/kimoto1/t2/network");
  $t->content_like(qr/Members of the t2/);
  $t->content_like(qr/My branch.*kimoto1.*t2.*master/s);
  $t->content_like(qr/Member branch.*kimoto2.*t2.*master/s);
  
  note 'Graph';
  {
    $t->get_ok("/kimoto1/t2/network/graph/master...kimoto2/t2/master");
    $t->content_like(qr/Graph/);
    $t->content_like(qr/first commit/);
  }
}

note 'Delete branch';
{
  my $app = Gitprep->new;
  my $t = Test::Mojo->new($app);
  $t->ua->max_redirects(3);
  
  # No delete branch button
  $t->get_ok("/kimoto1/t2/branches");
  $t->content_like(qr/Branches/);
  $t->content_unlike(qr/Delete branch/);
  
  # Can't delete branch when no login
  $t->post_ok('/kimoto1/t2/branches?op=delete', form => {branch => 'tmp_branch'})
    ->content_like(qr/Users/);
  

  # Login as kimoto1
  $t->post_ok('/_login?op=login', form => {id => 'kimoto1', password => 'a'});
  my $cmd = "git --git-dir=$rep_home/kimoto1/t2.git branch tmp_branch";
  system($cmd) == 0 or die "Can't execute git branch";
  $t->get_ok("/kimoto1/t2/branches");
  $t->content_like(qr/Delete branch/);
  $t->content_like(qr/tmp_branch/);
  
  # Delete branch
  $t->post_ok('/kimoto1/t2/branches?op=delete', form => {branch => 'tmp_branch'});
  $t->content_like(qr/Branch tmp_branch is deleted/);
  $t->get_ok('/kimoto1/t2/branches');
  $t->content_unlike(qr/tmp_branch/);
}

note 'import-branch';
{
  my $app = Gitprep->new;
  my $t = Test::Mojo->new($app);
  $t->ua->max_redirects(3);

  # Login as kimoto1
  $t->post_ok('/_login?op=login', form => {id => 'kimoto1', password => 'a'});
  $t->get_ok('/')->content_like(qr/Logined as kimoto1 /);

  # Create project
  $t->post_ok('/_new?op=create', form => {project => 'import-branch1', description => '', readme => 1});
  $t->get_ok('/kimoto1')->content_like(qr/import-branch1/);
  
  # Login as kimoto2
  $t->post_ok('/_login?op=login', form => {id => 'kimoto2', password => 'a'});
  $t->get_ok('/')->content_like(qr/Logined as kimoto2 /);

  # Fork kimoto1/import-branch1
  $t->get_ok("/kimoto1/import-branch1/fork");
  $t->content_like(qr#Repository is forked from /kimoto1/import-branch1#);

  # Access not valid user
  $t->get_ok('/kimoto1/import-branch1/network');
  $t->content_like(qr/Network/);
  $t->content_unlike(qr/Import/);
  $t->get_ok('/kimoto1/import-branch1/import-branch/kimoto2/import-branch1?remote-branch=master');
  $t->content_like(qr/ Index page /);
  
  # Show network page import button
  $t->get_ok('/kimoto2/import-branch1/network');
  $t->content_like(qr/Network/);
  $t->content_like(qr/Import/);
  
  # Import branch page access
  $t->get_ok('/kimoto2/import-branch1/import-branch/kimoto1/import-branch1?remote-branch=master');
  $t->content_like(qr/Import branch/);

  # Invalid parameters
  $t->post_ok('/kimoto2/import-branch1/import-branch/kimoto1/import-branch1?remote-branch=master&op=import');
  $t->content_like(qr/Branch name is empty/);
  
  # Import branch
  $t->post_ok('/kimoto2/import-branch1/import-branch/kimoto1/import-branch1?op=import', form => {
    branch => 'new1',
    'remote-branch' => 'master'
  });
  $t->content_like(qr#Success: import#);
  $t->get_ok('/kimoto2/import-branch1/branches')->content_like(qr/new1/);

  # Import same name branch fail
  $t->post_ok('/kimoto2/import-branch1/import-branch/kimoto1/import-branch1?op=import', form => {
    branch => 'new1',
    'remote-branch' => 'master'
  });
  $t->content_like(qr#already exists#);

  # Import force
  $t->post_ok('/kimoto2/import-branch1/import-branch/kimoto1/import-branch1?op=import', form => {
    branch => 'new1',
    'remote-branch' => 'master',
    force => 1
  });
  $t->content_like(qr#Success: force import#);
}

note 'Private repository and collaborator';
{
  unlink $db_file;
  rmtree $rep_home;

  my $app = Gitprep->new;
  my $t = Test::Mojo->new($app);
  $t->ua->max_redirects(3);

  # Create admin user
  $t->post_ok('/_start?op=create', form => {password => 'a', password2 => 'a'});
  $t->content_like(qr/Login page/);

  # Login success
  $t->post_ok('/_login?op=login', form => {id => 'admin', password => 'a'});
  $t->content_like(qr/Admin/);
  
  # Create user
  $t->post_ok('/_admin/user/create?op=create', form => {id => 'kimoto', password => 'a', password2 => 'a'});
  $t->content_like(qr/Success.*created/);
  $t->post_ok('/_admin/user/create?op=create', form => {id => 'kimoto2', password => 'a', password2 => 'a'});
  $t->content_like(qr/Success.*created/);

  # Login as kimoto
  $t->post_ok('/_login?op=login', form => {id => 'kimoto', password => 'a'});
  $t->get_ok('/')->content_like(qr/kimoto/);

  # Create repository
  $t->post_ok('/_new?op=create', form => {project => 't1', description => 'Hello', readme => 1});
  $t->content_like(qr/README/);
  
  # Check private repository
  $t->post_ok("/kimoto/t1/settings?op=private", form => {private => 1});
  $t->content_like(qr/Repository is private/);
  
  # Can access repository myself
  $t->get_ok("/kimoto/t1");
  $t->content_like(qr/README/);

  # Login as kimoto2
  $t->post_ok('/_login?op=login', form => {id => 'kimoto2', password => 'a'});
  $t->get_ok('/')->content_like(qr/kimoto2/);
  
  # Can't access private repository
  $t->get_ok("/kimoto/t1");
  $t->content_like(qr/t1 is private repository/);
  
  # Login as kimoto
  $t->post_ok('/_login?op=login', form => {id => 'kimoto', password => 'a'});
  $t->get_ok('/')->content_like(qr/kimoto/);
  
  # Add collaborator
  $t->post_ok("/kimoto/t1/settings/collaboration?op=add", form => {collaborator => 'kimoto2'});
  $t->content_like(qr/Collaborator kimoto2 is added/);
  
  # Login as kimoto2
  $t->post_ok('/_login?op=login', form => {id => 'kimoto2', password => 'a'});
  $t->get_ok('/')->content_like(qr/kimoto2/);
  
  # Can access private repository from collaborator
  $t->get_ok("/kimoto/t1");
  $t->content_like(qr/README/);

  # Login as kimoto
  $t->post_ok('/_login?op=login', form => {id => 'kimoto', password => 'a'});
  $t->get_ok('/')->content_like(qr/kimoto/);

  # Delete collaborator
  $t->post_ok("/kimoto/t1/settings/collaboration?op=remove", form => {collaborator => 'kimoto2'});
  $t->content_like(qr/Collaborator kimoto2 is removed/);

  # Login as kimoto2
  $t->post_ok('/_login?op=login', form => {id => 'kimoto2', password => 'a'});
  $t->get_ok('/')->content_like(qr/kimoto2/);

  # Can't access private repository
  $t->get_ok("/kimoto/t1");
  $t->content_like(qr/t1 is private repository/);
}
