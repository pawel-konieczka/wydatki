package Expenses;

use base 'CGI::Application';
use strict;
use utf8;

use CGI::Carp qw(fatalsToBrowser carpout);

use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::Authentication;
use CGI::Application::Plugin::AutoRunmode;
use CGI::Application::Plugin::Config::Simple;
use CGI::Application::Plugin::Redirect;
use CGI::Application::Plugin::Forward;

use Outcomes;
use Encode;
use Date::Simple qw(today);
use CGI::Cookie;
use MyException;

use Data::Dumper;

=tu
BEGIN {
     use CGI::Carp qw(carpout);
     open("LOG", ">>/usr/local/cgi-logs/error.log") or
       die("Unable to open mycgi-log: $!\n");
     carpout("LOG");
   }
=cut

sub cgiapp_init {
    my $self    = shift;

    $self->config_file('wydatki.ini');

    $self->param('debug' => $self->config_param('debug'));

    my $query   = $self->query;

    my $session_name = $self->config_param('session.name');
    my $sid     = $query->cookie($session_name) || $query->param($session_name) || undef;
    my %dsn_args = $self->config_param('session.dsn_args');


    $self->session_config(CGI_SESSION_OPTIONS => [$self->config_param('session.dsn'), $sid, \%dsn_args, {name => $session_name}],
			  COOKIE_PARAMS => {
			      -name    => $session_name,
			      -value   => $sid,
			      -expires => undef
			  },
			  SEND_COOKIE => 1,
	);

    if (!$sid or $sid ne $self->session->id ) {
	my $id = $self->session->id;

	$self->session_cookie(-name => $session_name,
			      -value => $id,
			      -expires => undef,
	    );

    }

    my $passwd = $self->config_param('db.passwd');
    $passwd = undef unless($passwd);

    my $db = Outcomes->new('host' => $self->config_param('db.host'),
			   'dbname' => $self->config_param('db.dbname'),
			   'user' => $self->config_param('db.user'),
			   'passwd' => $passwd,
			   'encoding' => $self->config_param('db.encoding'),
	);

    $self->param('db' => $db);

    my @authen_driver = ('Generic',
			 sub {
			     my ($user, $passwd) = @_;
                             return $self->param('db')->check_user($user, $passwd);
			 }
	);

    $self->authen->config(
	DRIVER => \@authen_driver,
	STORE => 'Session',
	CREDENTIALS => ['lg_nick', 'lg_pass'],
	POST_LOGIN_RUNMODE => 'auth_insert_html',
	LOGIN_RUNMODE => 'start',
	LOGOUT_RUNMODE => 'start',
	);

    $self->authen->protected_runmodes(qr/^auth_/);

}

sub cgiapp_prerun {
    my $self = shift;
    my $query = $self->query;


    if($self->query->param('authen_logout')) {
	$self->authen->logout();
	# dodatkowo czyscimy sesje
	$self->session->clear();
	$self->authen->redirect_to_logout();
    }

}

sub setup {
    my $self = shift;


    $self->mode_param('rm');

    $self->tmpl_path($self->config_param('application.tmpl_path'));
    
    my $user = $self->param('db')->get_user_by_name($self->authen->username);
    my $user_id = ($user eq undef) ? undef : $user->{'ID'};

    #die $user . " " . $user_id;

    my $session = $self->session;

    $session->param('user_id' => $user_id);

    my @datetime = localtime(time);
    my $year = $session->param('current_year') || $datetime[5] + 1900;

    $session->param('current_year' => $year);

}

sub teardown
{
    my $self = shift;

    $self->session->flush();
}

sub start : RunMode {
    my $self = shift;
    
    my $template = $self->get_template('login.html');

    eval {
	$self->check_db_version();
	1;
    } or do {
	
	my $tmpl = $self->get_error_page($@);

	return $tmpl->output();
    };

    my @credentials = @{$self->authen->credentials};
    $template->param(CRED_LOGIN => $credentials[0],
		     CRED_PASSWORD => $credentials[1],);

    my $conf_file = $self->config_file();
    $self->config_file('version');
    $template->param(VERSION => $self->config_param('version'),
		     MOD_DATE => $self->config_param('modification_date'),
	);
    $self->config_file($conf_file);

    return $template->output();
}

sub test : RunMode {
    my $self = shift;

    my $template = $self->get_template('test.html');

    my @table = ( {'text' => 'abc',
		   'order' => '1',
		  'id' => 0},
		  {'text' => 'ąbc',
		   'order' => '2',
		  'id' => 1},
		  {'text' => 'ćbc',
		   'order' => '5',
		  'id' => 2},
		  {'text' => 'bbc',
		   'order' => '3',
		  'id' => 3},
		  {'text' => 'cbc',
		   'order' => '4',
		  'id' => 4}
	);

    $template->param(TABLE => \@table);

    return $template->output();

}

sub auth_select_year_html : RunMode {

    my $self = shift;
    
    my $template = $self->get_template('select_year.html');

    $template->param(PAGE_NAME => 'wybór roku finansowego');

    my $select_years = $self->param('db')->{'dbh'}->prepare("SELECT DISTINCT YEAR(Date) AS year FROM oc_data ORDER BY year DESC");
    my $res = $select_years->execute();
    Outcomes::check_result($res);

    my $years = $select_years->fetchall_arrayref({});
    $template->param(AVAILABLE_YEARS => $years);

    return $template->output();
}

sub auth_select_year : RunMode {
    my $self = shift;

    my $query = $self->query();
    my $session = $self->session;

    $session->param('current_year' => $query->param('year'));
    $session->flush();
    
    return $self->redirect('wydatki.cgi?rm=auth_menu');
}


sub auth_menu : RunMode {
    my $self = shift;

    my $template = $self->get_template('menu.html');

    return $template->output();
}


sub auth_insert_html : RunMode {
    my $self = shift;

    my $query = $self->query();

    my $template = $self->get_template('insert.html');
    $template->param(PAGE_NAME => 'wprowadzanie');

    my $date = $query->param('date') || today();
    my $descr = decode_data($query->param('description')) || '';
    my $value = $query->param('value') || '0.00';
    my $categoryid = $query->param('categoryid') || 0;
    my $details = decode_data($query->param('details')) || '';
    my $discount = $query->param('discount') || 0;


    my $categories = $self->get_categories($categoryid);
    my $descr_list = $self->get_descriptions();

    $template->param(DATE => $date,
		     DESCRIPTION => $descr,
		     DESCRIPTION_LIST => $descr_list,
		     VALUE => $value,
		     CATEGORIES => $categories,
		     DETAILS => $details,
		     DISCOUNT => $discount,
	);

    

    return $template->output();
}


sub auth_addoutcome : RunMode {
    my $self = shift;

    my $query = $self->query();

    my $outcome = $self->prepare_outcome();

    if($outcome eq undef) {
	return $self->forward('auth_insert_html');
    }

    $self->param('db')->add_outcome($outcome);
    
    my $date = $query->param('date');

    return $self->redirect('wydatki.cgi?rm=auth_insert_html&date='.$date);
}


sub auth_replist_html : RunMode {
    my $self = shift;

    my $query = $self->query();
    my $year = $self->session->param('current_year');

    my $month = $self->filter_param('month', get_current_month());
    my $category = $self->filter_param('category', 0);
    my $user = $self->filter_param('user', 0);
    my $descr = decode_data($self->filter_param('description', ''));
    my $details = decode_data($self->filter_param('details', ''));
    my $discounted = $self->filter_param('discount', '');
    my $date_from = $self->filter_param('date_from', '');
    my $date_to = $self->filter_param('date_to', '');
    my $date_enabled = $self->filter_param('date_enabled', '');
    my $sort = $self->filter_param('sort', '');

    my $extended_filter = $self->filter_param('extended', 0);

    my $descr_list = $self->get_descriptions();

    my $template = $self->get_template('report_list.html');
    $template->param(PAGE_NAME => 'lista wydatków w roku finansowym');

    $template->param(SORT_BY => $sort);

#    my $list_ref = $self->param('db')->get_outcomes_list_by_year($year);
    my $list_ref = $self->param('db')->get_outcomes_list('year' => $year,
							 'month' => $month,
							 'category' => $category,
							 'user' => $user,
							 'description' => $descr,
							 'details' => $details,
							 'discount' => $discounted,
							 'date_from' => $date_enabled ? $date_from : undef,
							 'date_to' => $date_enabled ? $date_to : undef,
	);

    my $total_sum = 0;
    my $counter = 0;
    for my $item (@{$list_ref}) {
	$item->{'description'} = decode_data($item->{'description'});
	$item->{'category'} = decode_data($item->{'category'});
	$item->{'value'} = sprintf("%.2f", $item->{'value'});
	$total_sum += $item->{'value'};
	$item->{'details'} = decode_data($item->{'details'});
	$item->{'details'} =~ s/[\n\r]+/<br>/g;
	$item->{'no'} = $counter;
	++$counter;
    }


    
    $template->param(OUTCOMES => $list_ref,
		     TOTAL_SUM => $total_sum
	);
    
    my @categories = map { {
	'category_id' => $_->{'id'}, 
	'category_name' => $_->{'name'},
	'category_name_id' => $_->{'name_id'},
	'selected' => $_->{'id'}==$category ? 1 : 0 } } 
    @{$self->get_categories()};
    unshift @categories, {'category_id' => 0, 'category_name' => 'Wszystkie', 'category_name_id' => undef,};
    
    $template->param(CATEGORIES => \@categories);


    my @months;
    
    my @month_names = qw(Wszystkie Styczeń Luty Marzec Kwiecień Maj Czerwiec Lipiec Sierpień Wrzesień Październik Listopad Grudzień);

    for (0..@month_names-1) {
	push @months, {"month" => $_, 
		       "month_name" => $month_names[$_],
		       'selected' => $_==$month ? 1 : 0};
    }

    $template->param(MONTHS => \@months);


    my @users = map { {
	"user_id" => $_->{'id'}, 
	"user_name" => $_->{'user'},
	'selected' => $_->{'id'}==$user ? 1 : 0} } 
    @{$self->param('db')->get_user_list()};
    unshift @users, {"user_id" => 0, "user_name" => "Dowolny"};

    $template->param(USERS => \@users);
    $template->param(DESCRIPTION => $descr,
		     DESCRIPTION_LIST => $descr_list);
    $template->param(DETAILS => $details);
    $template->param(CHECK_FILTER_DISCOUNT_0 => ($discounted == 0 && $discounted ne '') ? 1 : 0,
		     CHECK_FILTER_DISCOUNT_1 => $discounted == 1 ? 1 : 0,
		     CHECK_FILTER_DISCOUNT_NULL => $discounted eq '' ? 1 : 0
		     );
    $template->param(DATE_FROM => $date_from,
		     DATE_TO => $date_to,
		     DATE_ENABLED => $date_enabled
	);

    $template->param(SHOW_EXTENDED_FILTER => $extended_filter);

    return $template->output();
}


sub auth_catreport_html : RunMode {
    my $self = shift;

    my $year = $self->session->param('current_year');

    my $template = $self->get_template('report_category.html');
    $template->param(PAGE_NAME => 'raport w kategoriach');


    my $list_ref = $self->param('db')->get_outcomes_list_by_category($year);

    my $sum_monthly = 0;
    my $sum_total = 0;
    my $counter = 0;
    for my $item (@{$list_ref}) {
	$item->{'category'} = decode_data($item->{'category'});
	$item->{'monthly'} = sprintf("%.2f", $item->{'monthly'});
	$item->{'total'} = sprintf("%.2f", $item->{'total'});
	$item->{'style'} = ($counter % 2) ? 'even' : 'odd';
	$sum_monthly += $item->{'monthly'};
	$sum_total += $item->{'total'};
	++$counter;
    }

    push(@{$list_ref}, {'category' => 'Łącznie', 
			'monthly' => $sum_monthly, 
			'total' => $sum_total,
			'style' => ($counter % 2) ? 'even' : 'odd', 
	 });

    $template->param(YEAR => $year,
		     OUTCOMES => $list_ref,
	);

    return $template->output();
}


sub auth_monthreport_html : RunMode {
    my $self = shift;

    my $year = $self->session->param('current_year');

    my $template = $self->get_template('report_monthly.html');
    $template->param(PAGE_NAME => 'raport w miesiącach');

    my @month_names = ( 'styczeń',
               'luty',
               'marzec',
               'kwiecień',
	       'maj',
               'czerwiec',
               'lipiec',
               'sierpień',
               'wrzesień',
               'październik',
               'listopad',
	       'grudzień'
	);

    my $month = $self->query()->param('month');

    unless($month) {
	$month = get_current_month();
    }

    # wybieramy dostepne miesiace z wydatkami
    my $sql = 'SELECT MIN(MONTH(d.Date)) as minMonth, MAX(MONTH(d.Date)) as maxMonth ' .
	' FROM `oc_data` d' .
	' WHERE YEAR(d.Date) = ?';
    my $select_months = $self->param('db')->{'dbh'}->prepare($sql);
    my $res = $select_months->execute($year);
    Outcomes::check_result($res);

    my ($minMonth, $maxMonth) = $select_months->fetchrow_array();

    my @months;

    for(my $i = $minMonth; $i<=$maxMonth; ++$i) {
	my $selected = $month == $i ? 1 : 0;
	push @months, {MONTH_ID => $i, MONTH_NAME => $month_names[$i-1], SELECTED => $selected};
    }
    

    my $list_ref = $self->param('db')->get_outcomes_list_by_month($year, $month);

    my $counter = 0;
    for my $item (@{$list_ref}) {
	$item->{'category'} = decode_data($item->{'category'});
	$item->{'sum'} = sprintf("%.2f", $item->{'sum'});
	$item->{'style'} = ($counter % 2) ? 'even' : 'odd';
	++$counter;
    }
    
    my $total_sum = sprintf("%.2f", $self->param('db')->get_total_outcomes_by_month($year, $month));


    $template->param(YEAR => $year,
		     MONTHS => \@months,
		     OUTCOMES => $list_ref,
		     TOTAL_SUM => $total_sum,
	);

    return $template->output();
}

sub auth_edit_item_html : RunMode {
    my $self = shift;

    my $id = $self->query->param('id');

    my $template = $self->get_template('edit_item.html');
    $template->param(PAGE_NAME => 'edycja pozycji');

    my $outcome = $self->param('db')->get_outcome($id);
    $outcome->{'Description'} = decode_data($outcome->{'Description'});
    $outcome->{'Details'} = decode_data($outcome->{'Details'});

#    die Dumper($outcome);

    $template->param(ID => $outcome->{'ID'},
		     DATE => $outcome->{'Date'},
		     DESCRIPTION => $outcome->{'Description'},
		     VALUE => sprintf("%.2f", $outcome->{'Value'}),
		     CATEGORIES => $self->get_categories($outcome->{'CategoryID'}),
		     DETAILS => $outcome->{'Details'},
		     DISCOUNT => $outcome->{'Discount'},
	);

    return $template->output();
}

sub auth_update_item : RunMode {
    my $self = shift;

    my $query = $self->query;


    if($query->param('save')) {

	my $outcome = $self->prepare_outcome();
		
	if($outcome eq undef) {
	    return $self->forward('auth_edit_item_html');
	}
	
	$self->param('db')->update_outcome($outcome);
	
    }
    elsif($query->param('delete')) {
	$self->param('db')->remove_outcome($query->param('id'));
    }

    return $self->redirect('wydatki.cgi?rm=auth_replist_html');
}

sub auth_edit_category_html : RunMode {
    my $self = shift;

    my $query = $self->query();

    my $action = $query->param('action');
    my $id = $query->param('id');

    my $template = $self->get_template('edit_category.html');
    $template->param(PAGE_NAME => 'edycja kategorii');

    my $categories = $self->get_categories();

    for my $cat (@{$categories}) {
	$cat->{'used'} = $self->param('db')->is_category_used($cat->{'id'});
	if($cat->{'id'} == $id) {
	    $cat->{'edited'} = 1;
	}
    }

    $template->param(CATEGORIES => $categories);

    if($action eq 'edit' || $action eq 'add') {
	$template->param(ACTION => $action);
	my $cat = $self->param('db')->get_category($id);
	$cat->{'Name'} = decode_data($cat->{'Name'});
	$cat->{'Description'} = decode_data($cat->{'Description'});

	my $positions = $self->param('db')->get_category_positions();

	for my $pos (@{$positions}) {
	    push @{$cat->{'positions'}}, {'position' => $pos, 
					  'selected' => ($pos == $cat->{'Position'}) ? 1 : 0,
					  'name' => get_position_name($pos)
	    };
	}

	if($action eq 'add') {
	    my $pos = @{$cat->{'positions'}}[-1]->{'position'} + 1;
	    push @{$cat->{'positions'}}, {'position' => $pos,
					  'selected' => 1,
					  'name' => get_position_name($pos),
	    };
	}

	delete $cat->{'Position'};

	$template->param($cat);
    } 

    return $template->output();
}

sub auth_edit_category : RunMode {
    my $self = shift;

    my $query = $self->query();

    my $action = $query->param('action');
    my $id = $query->param('id');

    if(defined $query->param('cancel')) {
	return $self->redirect('?rm=auth_edit_category_html');
    }

    if($action eq 'delete') {
	$self->param('db')->remove_category($id);
	return $self->redirect('?rm=auth_edit_category_html');
    }

    my $cat = $self->prepare_category();
    if($cat eq undef) {
	return $self->forward('auth_edit_category_html');
    }

    if($action eq 'edit') {
	$self->param('db')->update_category($cat);
    } elsif($action eq 'add') {
	$self->param('db')->add_category($cat);
    }
    

    return $self->redirect('?rm=auth_edit_category_html');

}

sub auth_change_passwd_html : RunMode {
    my $self = shift;

    my $query = $self->query();

    my $template = $self->get_template('change_password.html');
    $template->param(PAGE_NAME => 'zmiana has&#x0142;a');

    my $error = ($query->param('authentication_failed') || $query->param('unmatched_password')) ? 1 : 0;
    $template->param(ERROR => $error,
	);
    $template->param(AUTHENTICATION_FAILED => $query->param('authentication_failed'));
    $template->param(UNMATCHED_PASSWD => $query->param('unmatched_password'));

    return $template->output();
}

sub auth_change_passwd : RunMode {
    my $self = shift;

    my $query = $self->query();

    my $current_passwd = $query->param('current_passwd');
    my $new_passwd = $query->param('new_passwd');
    my $new_passwd2 = $query->param('new_passwd2');

    my $username = $self->authen->username;

    unless($self->param('db')->check_user($username, $current_passwd)) {
	return $self->redirect('wydatki.cgi?rm=auth_change_passwd_html&authentication_failed=1');
    }

    if($new_passwd ne $new_passwd2 || !$new_passwd) {
	return $self->redirect('wydatki.cgi?rm=auth_change_passwd_html&unmatched_password=1');
    }

    $self->param('db')->set_password($username, $new_passwd);

    return $self->redirect('wydatki.cgi?rm=auth_menu');
}

sub auth_settings_html : RunMode {
    my $self = shift;

    my $query = $self->query();

    my $template = $self->get_template('settings.html');
    $template->param(PAGE_NAME => 'ustawienia');

    return $template->output();
}

sub auth_get_category_for_descr : RunMode {
    my $self = shift;

    my $descr = $self->query()->param('description');

    my $cat_array_ref = $self->param('db')->get_category_for_descr($descr);

    return $cat_array_ref->[0] if(ref($cat_array_ref) eq 'ARRAY');
    
    return 1;
}

sub auth_update_filter : RunMode {
    my $self = shift;

    my $filter_name = $self->query->param('fname');
    my $filter_value = $self->query->param('fvalue');

    $self->session->param('filter_'.$filter_name => $filter_value);
    $self->session->flush();

    return 1;
}

sub get_error_page {
    my ($self, $err_msg) = @_;

    $err_msg =~ s/\n/<br>/g;

    my $template = $self->get_template('error.html');
    $template->param(ERROR_MSG => $err_msg);

    return $template;
}

sub get_template {
    my ($self, $filename) = @_;

    my $template = $self->load_tmpl($filename);

    $template->param(APP_NAME => $self->config_param('application.name'));


    my $style_path = $self->config_param('application.style_path');
    my @style_files = map { 
	{STYLE_PATH => ($_ =~ /^http:\/\//) ? undef : $style_path,
	 STYLE_FILENAME => $_}  
    } $self->config_param('application.style_files');

    $template->param(STYLE_FILES => \@style_files);


    my $script_path = $self->config_param('application.script_path');

    my @script_files = map { 
	{SCRIPT_PATH =>  ($_ =~ /^http:\/\//) ? undef : $script_path,
	 SCRIPT_FILENAME => $_}  
    } $self->config_param('application.script_files');

    $template->param(SCRIPT_FILES => \@script_files);



    return $template;

}

sub get_categories {
    my ($self, $current_category) = @_;

    my $categories = $self->param('db')->get_category_list();


    for my $cat (@{$categories}) {
	$cat->{'name'} = decode_data($cat->{'name'});
	$cat->{'description'} = decode_data($cat->{'description'});
	if ($cat->{'id'} == $current_category) {
	    $cat->{'selected'} = 1;
	}
	$cat->{'name_id'} = get_position_name($cat->{'position'});
	delete $cat->{'position'};
    }

    return $categories;
}


sub get_descriptions {
    my ($self) = @_;

    my @descr_list = map {$_->{'description'} = decode_data($_->{'description'}); $_} @{$self->param('db')->get_description_list()};

    return \@descr_list;
}


sub prepare_outcome {
    my $self = shift;


    my $query = $self->query();


    my $year = $self->session->param('current_year');
    my $autor = $self->session->param('user_id');

    my $id = $query->param('id');
    my $date = $query->param('date');
    my $descr = $query->param('description');
    my $value = $query->param('value');
    my $category = $query->param('categoryid');
    my $details = $query->param('details');
    my $discount = $query->param('discount') || 0;

    $value =~ s/,/./;


    if($date eq '' ||
       $descr eq '' ||
       $value eq '' ||
       $value == 0 ||
       $category == 0) {
	return undef;
    }
	
    my %outcome = ('id' => $id,
		   'year' => $year,
		   'userid' => $autor,
		   'date' => $date,
		   'description' => $descr,
		   'value' => $value,
		   'categoryid' => $category,
		   'details' => $details,
		   'discount' => $discount,
	);


    return \%outcome;
}

sub prepare_category {
    my $self = shift;

    my $query = $self->query();

    my $id = $query->param('id');
    my $name = $query->param('name');
    my $descr = $query->param('description');
    my $pos = $query->param('position');
    
    if($name eq '') {
	return undef;
    }
    if($pos eq '') {
	return undef;
    }
    
    return { id => $id,
	     name => $name,
	     description => $descr,
	     position => $pos
    };
}

sub check_db_version {
    my $self = shift;

    my $cur_db_version = $self->param('db')->get_config('version')->{'version'};
    my $db_version = $self->config_param('db.version');

    if($cur_db_version eq $db_version) {
	return 1;
    }
    
    # niezgodne wersje interfejsu i bazy danych
    die MyException->new("Wersja bazy danych jest niezgodna z interfejsem\n(wersja aktualna: $cur_db_version  wersja oczekiwana: $db_version)");

}

sub get_position_name {
    my $position = shift;

    my @ids = ('0'..'9', 'A'..'Z');

    return $ids[$position];
    
}

sub decode_data {
    my $str_data = shift;

    return decode('utf-8', $str_data);
}

sub get_current_month {
    my $date = today();
    my $month = $date->month;
    $month =~ s/^0//;
    return $month;
}

sub filter_param {
    my $self = shift;
    my $filter_name = shift;
    my $default = shift;

    my $value = $self->query->param($filter_name);
#    print STDERR "v1=$value<br>\n";
    if(! defined $value) {
	$value = $self->session->param('filter_'.$filter_name);
    } else {
#	print STDERR "wstawiam do sesji\n";
	$self->session->param('filter_'.$filter_name => $value);
	$self->session->flush();
    }
#    print STDERR "v2=$value<br>\n";
    $value = $default if(! defined $value);
#    print STDERR "v3=$value<br>\n";

    return $value;
}

return 1;
