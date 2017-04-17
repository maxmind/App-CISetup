#!/usr/bin/perl

use App::CISetup::Wrapper::Ourperl;

use App::CISetup::Travis::ConfigUpdater;
App::CISetup::Travis::ConfigUpdater->new_with_options->run;

__END__

=pod

=head1 NAME - App::CISetup::Travis::ConfigUpdater

=head1 DESCRIPTION

Update existing .travis.yml files with Slack and notification settings

=head1 GETTING STARTED

You'll need to have the Travis CLI installed.  On a linux box this would be
something like

    sudo apt-get install ruby1.9.1-dev
    sudo gem install travis -v 1.8.2 --no-rdoc --no-ri

You'll need a non-empty .travis.yml file in your repo to get started.  Something
like this is enough:

   ---
   sudo: false

Though if you are building a Perl repository you'll need to add a before
install step so that the config updater will recognize this is a Perl
distro and expand to the full config

    ---
    sudo: false
    before_install:
      - eval $(curl https://travis-perl.github.io/init) --auto

Now you just need to invoke this script with a --dir for your repository:

    update-travis-yml.pl --dir ~/checkouts/MyRepoName

If you want email or slack notification you'll need to pass a few more param:

    update-travis-yml.pl \
       --github-user example \
       --slack-key o8PZMLqZK6uWVxyyTzZf4qdY \
       --email-address example@example.org

