package Outcomes;

use strict;
use DBI;

use Data::Dumper;


sub check_result {
    my $res = shift;
    if($res eq undef) {
	die DBI::errstr;
    }
}

sub new
{
    my $class = shift;
    my %args = @_;

    my $host = $args{'host'};
    my $dbname = $args{'dbname'};
    my $user = $args{'user'};
    my $passwd = $args{'passwd'};
    my $encoding = $args{'encoding'};
    my $debug = $args{'debug'};

    if(!$encoding) {
	$encoding = 'utf8';
    }

    my $dbh = DBI->connect("dbi:mysql:dbname=$dbname;host=$host", $user, $passwd) or die "Blad polaczenia z baza: $dbname (".$DBI::errstr.")\n";

    # zamiast warning użyj error
    $dbh->do("SET sql_mode=?", undef, 'traditional');

    $dbh->do("SET NAMES ?", undef, $encoding);

    my $this =
    {
	'dbh' => $dbh,
	'dbname' => $dbname,
	'config_h' => $dbh->prepare("SELECT * FROM oc_config"),
	'category_list_h' => $dbh->prepare("SELECT id, name, description, position FROM oc_categories ORDER BY position"),
	'description_list_h' => $dbh->prepare("SELECT description FROM oc_data GROUP BY description ORDER BY count(*) DESC, LOWER(description)"),
	'user_list_h' => $dbh->prepare("SELECT id, user FROM oc_users ORDER BY id"),
	'insert_outcome_h' => $dbh->prepare("INSERT INTO oc_data(Description, Date, CategoryID, Value, Details, Discount, UserID) VALUES(?,?,?,?,?,?,?)"),
	'select_outcomes_by_year_h' => $dbh->prepare("SELECT D.id, D.date, D.value, D.description, U.user as author,  C.name AS category FROM oc_data D LEFT JOIN oc_categories C ON(D.categoryID=C.ID) LEFT JOIN oc_users U ON(D.UserID=U.ID) WHERE YEAR(D.date)=? ORDER BY D.date DESC"),
	'delete_outcome_h' => $dbh->prepare("DELETE FROM oc_data WHERE ID=?"),
	'select_user_by_name_h' => $dbh->prepare("SELECT * FROM oc_users WHERE User=?"),
	'update_usser_passwd_h' => $dbh->prepare("UPDATE oc_users SET passwd=PASSWORD(?) WHERE user=?"),
	'select_outcome_h' => $dbh->prepare("SELECT * FROM oc_data WHERE ID=?"),
	'select_category_h' => $dbh->prepare("SELECT * FROM oc_categories WHERE ID=?"),
	'select_category_for_description_h' => $dbh->prepare("SELECT CategoryId FROM oc_data GROUP BY CategoryId, Description HAVING Description=? ORDER BY count(*) DESC"),
	'update_outcome_h' => $dbh->prepare("UPDATE oc_data SET Description=?, Date=?, CategoryID=?, Value=?, Details=?, Discount=? WHERE ID=?"),
	'update_category_h' => $dbh->prepare("UPDATE oc_categories set Name=?, Description=?, Position=? WHERE ID=?"),
	'insert_category_h' => $dbh->prepare("INSERT INTO oc_categories(Name, Description, Position) VALUES(?,?,?)"),
	'delete_category_h' => $dbh->prepare("DELETE FROM oc_categories WHERE ID=?"),
    };

    bless $this, $class;
    return $this;
}


sub get_user_by_name {
   my ($self, $username) = @_;

   my $res = $self->{'select_user_by_name_h'}->execute($username);

   if($res eq undef) {
       die DBI::errstr;
   }

   my $user = $self->{'select_user_by_name_h'}->fetchrow_hashref();


   return $user;
}

sub check_user {
    my ($self, $username, $passwd) = @_;

    my $user = $self->get_user_by_name($username);

    return 0 if($user eq undef);

    my $sth = $self->{'dbh'}->prepare("SELECT COUNT(*) FROM oc_users WHERE ID=? AND Passwd=PASSWORD(?)");
    $sth->execute($user->{'ID'}, $passwd);

    my $exists = ($sth->fetchrow_array())[0];

    return  $exists ? $user->{'User'} : 0;
}

sub get_category_list {
    my $self = shift;

    my $res = $self->{'category_list_h'}->execute();

    if($res eq undef) {
	die DBI::errstr;
    }

    my $categories = $self->{'category_list_h'}->fetchall_arrayref({});

    return $categories;
}
sub get_description_list {
    my $self = shift;

    $self->{'description_list_h'}->execute();

    my $descriptions = $self->{'description_list_h'}->fetchall_arrayref({});

     return $descriptions;
}

sub get_user_list {
    my $self = shift;
    $self->{'user_list_h'}->execute();
    my $users = $self->{'user_list_h'}->fetchall_arrayref({});
    return $users;
}

sub get_outcome {
    my ($self, $id) = @_;
    
    my $res = $self->{'select_outcome_h'}->execute($id);

    if($res eq undef) {
	die DBI::errstr;
    }

    return $self->{'select_outcome_h'}->fetchrow_hashref();
}

sub get_category {
    my ($self, $id) = @_;

    my $res = $self->{'select_category_h'}->execute($id);

    if($res eq undef) {
	die DBI::errstr;
    }

    return $self->{'select_category_h'}->fetchrow_hashref();
}

sub get_category_for_descr {
    my ($self, $descr) = @_;

    my $res = $self->{'select_category_for_description_h'}->execute($descr);

    if($res eq undef) {
	die DBI::errstr;
    }

    my @categories = map {$_->[0]} @{$self->{'select_category_for_description_h'}->fetchall_arrayref([0])};


    return \@categories;
}

sub get_category_positions {
    my ($self) = @_;

    my $sth = $self->{'dbh'}->prepare('SELECT Position from oc_categories ORDER BY Position');
    my $res = $sth->execute();

    if($res eq undef) {
	die DBI::errstr;
    }

    my @positions = map {$_->[0]} @{$sth->fetchall_arrayref([0])};

    return \@positions;
}

sub update_category {
    my ($self, $category) = @_;

    my ($sth, $res);

    my $c = $self->get_category($category->{'id'});

    $self->{'dbh'}->{AutoCommit} = 0;
    
    eval {
    if($c->{'position'} != $category->{'position'}) {
	
	$sth = $self->{'dbh'}->prepare('UPDATE oc_categories SET Position = Position - 1 WHERE Position > ?');
	$res = $sth->execute($c->{'Position'});
	
	if($res eq undef) {
	    die DBI::errstr;
	}


	$sth = $self->{'dbh'}->prepare('UPDATE oc_categories SET Position = Position + 1 WHERE Position >= ?');
	$res = $sth->execute($category->{'position'});
	
	if($res eq undef) {
	    die DBI::errstr;
	}

    }

    $res = $self->{'update_category_h'}->execute(
	$category->{'name'},
	$category->{'description'},
	$category->{'position'},
	$category->{'id'}
	);
    
    if($res eq undef) {
	die DBI::errstr;
    }

    };

    my $error = $@;

    if($error) {
	$self->{'dbh'}->rollback;
    } else {
	$self->{'dbh'}->commit;
    }

    die $error if($error);
}

sub add_category {
    my ($self, $category) = @_;

    my ($sth, $res);

    $sth = $self->{'dbh'}->prepare("UPDATE oc_categories SET Position = Position + 1 WHERE Position >= ?");
    $res = $sth->execute($category->{'position'});

    if($res eq undef) {
	die DBI::errstr;
    }

    my $res = $self->{'insert_category_h'}->execute(
	$category->{'name'},
	$category->{'description'},
	$category->{'position'},
	);

    if($res eq undef) {
	die DBI::errstr;
    }

}

sub remove_category {
    my ($self, $id) = @_;

    my $c = $self->get_category($id);

    my $res = $self->{'delete_category_h'}->execute($id);

    if($res eq undef) {
	die DBI::errstr;
    }

    my ($sth, $res);

    $sth = $self->{'dbh'}->prepare("UPDATE oc_categories SET Position = Position - 1 WHERE Position >= ?");
    $res = $sth->execute($c->{'Position'});

    if($res eq undef) {
	die DBI::errstr;
    }

}

sub add_outcome {

    my $self = shift;
    my $outcome = shift;

    my $res = $self->{'insert_outcome_h'}->execute(
	$outcome->{'description'},
	$outcome->{'date'},
	$outcome->{'categoryid'},
	$outcome->{'value'},
	$outcome->{'details'},
	$outcome->{'discount'},
	$outcome->{'userid'},
	);

    if($res eq undef) {
	die DBI::errstr;
    }

}

sub remove_outcome {
    my ($self, $id) = @_;

    my $res = $self->{'delete_outcome_h'}->execute($id);

    if($res eq undef) {
	die DBI::errstr;
    }
}

sub update_outcome {
    my $self = shift;
    my $outcome = shift;

    my $res = $self->{'update_outcome_h'}->execute(
	$outcome->{'description'},
	$outcome->{'date'},
	$outcome->{'categoryid'},
	$outcome->{'value'},
	$outcome->{'details'},
	$outcome->{'discount'},
	$outcome->{'id'},
	);

    if($res eq undef) {
	die DBI::errstr;
    }
}

sub get_outcomes_list {
    my ($self, %args) = @_;
    my $year = $args{'year'};
    my $month = $args{'month'};
    my $category = $args{'category'};
    my $user = $args{'user'};
    my $descr = $args{'description'};
    my $details = $args{'details'};
    my $discount = $args{'discount'};
    my $date_from = $args{'date_from'};
    my $date_to = $args{'date_to'};

    my $date = ($date_from ne undef && $date_to ne undef);

    my $sql = "SELECT D.id, D.date, D.value, D.description, D.details, U.user as author,  C.name AS category, D.discount FROM oc_data D LEFT JOIN oc_categories C ON(D.categoryID=C.ID) LEFT JOIN oc_users U ON(D.UserID=U.ID) WHERE 0=0 ";
    my @sql_params = ();

    if(! $date) {
	$sql .= " AND YEAR(D.date)=? ";
	push @sql_params, $year;
	if($month) {
	    $sql .= "AND month(D.date)=? ";
	    push @sql_params, $month;
	}
    }
    if($category) {
	$sql .= " AND C.id=? ";
	push @sql_params, $category;
    }
    if($user) {
	$sql .= " AND U.id=? ";
	push @sql_params, $user;
    }
    if($descr ne undef) {
	$sql .= " AND lower(D.description) REGEXP lower(?) ";
	push @sql_params, $descr;
    }
    if($details ne undef) {
	$sql .= " AND lower(D.details) REGEXP lower(?) ";
	push @sql_params, $details;
    }
    if($discount ne undef) {
	$sql .= " AND D.discount=? ";
	push @sql_params, $discount;
    }
    if($date) {
	$sql .= " AND D.date>=? AND D.date<=? ";
	push @sql_params, $date_from;
	push @sql_params, $date_to;
    } else {
    }

    $sql .= "ORDER BY D.date DESC";


    my $select_outcomes = $self->{'dbh'}->prepare($sql);
    my $res = $select_outcomes->execute(@sql_params);

    if($res eq undef) {
	die DBI::errstr;
    }

    return $select_outcomes->fetchall_arrayref({});

}

sub get_outcomes_list_by_year {
    my $self = shift;
    my $year = shift;

    my $res = $self->{'select_outcomes_by_year_h'}->execute($year);

    if($res eq undef) {
	die DBI::errstr;
    }

    return $self->{'select_outcomes_by_year_h'}->fetchall_arrayref({});
}

sub get_outcomes_list_by_category {
    my ($self, $year) = @_;
    
    # pomijamy biezacy miesiac

    # liczba miesiecy
    my $select_month_count = $self->{'dbh'}->prepare("SELECT max(MONTH(d.Date)) - min(MONTH(d.Date)) + 1 FROM oc_data d WHERE YEAR(d.Date)=? AND d.date < date(concat(year(now()), '-', month(now()), '-01'))");
    my $res = $select_month_count->execute($year);

    if($res eq undef) {
	die DBI::errstr;
    }

    my $monthCnt = ($select_month_count->fetchrow_array())[0];

    return undef if($monthCnt == 0);

    # suma po kategoriach
    my $sql = 'SELECT c.Name as category, ' .
	'       sum(d.Value)/? as monthly,' .
	'       sum(d.Value) as total' .
	'  FROM `oc_categories` c' .
	'  LEFT JOIN `oc_data` d' .
	'  ON (c.ID = d.CategoryID)' .
	" WHERE YEAR(d.Date) = ? AND d.Date < date(concat(year(now()), '-', month(now()), '-01')) AND NOT d.Discount " .
	'  group by c.ID';

    my $select_list = $self->{'dbh'}->prepare($sql);
    $res = $select_list->execute($monthCnt, $year);


    if($res eq undef) {
	die DBI::errstr;
    }

    return $select_list->fetchall_arrayref({});
}

sub get_outcomes_list_by_month {
    my ($self, $year, $month) = @_;

    # wydatki w podanym miesiacu
    my$sql = 'SELECT' .
	' c.Name as category, d.sum' .
	' FROM `oc_categories` c' .
	' LEFT JOIN (SELECT CategoryID as CID, ' .
	'                   sum(value) as sum' .
	'            FROM `oc_data`' .
	'            WHERE MONTH(Date) = ?'.
	'            AND YEAR(Date) = ?' .
	'            AND NOT Discount'.
	'            GROUP BY CategoryID) d' .
	' ON ( c.id = d.CID )';
    
    my $select_month_outcome = $self->{'dbh'}->prepare($sql);

    my $res = $select_month_outcome->execute($month, $year);

    if($res eq undef) {
	die DBI::errstr;
    }

    return $select_month_outcome->fetchall_arrayref({});

}

sub get_total_outcomes_by_month {
    my ($self, $year, $month) = @_;

    # podsumowanie laczne
    my $sql = 'SELECT' .
	' sum(value) as sum' .
	' FROM `oc_data`' .
	' WHERE MONTH(Date) = ?'.
	' AND YEAR(Date) = ?'.
	' AND NOT Discount';

    my $select_sum = $self->{'dbh'}->prepare($sql);

    my $res = $select_sum->execute($month, $year);

    if($res eq undef) {
	die DBI::errstr;
    }

    return ($select_sum->fetchrow_array())[0];
}

sub is_category_used {
    my ($self, $id) = @_;

    my $sth = $self->{'dbh'}->prepare('SELECT COUNT(*) FROM oc_data WHERE CategoryID=?');
    my $res = $sth->execute($id);

    if($res eq undef) {
	die DBI::errstr;
    }

    return $sth->fetchrow_array();
    
}

sub set_password {
    my ($self, $username, $passwd) = @_;

    my $res = $self->{'update_usser_passwd_h'}->execute($passwd, $username);

    if($res eq undef) {
	die DBI::errstr;
    }
}

sub get_config {
    my ($self, @params) = @_;

    my $res = $self->{'config_h'}->execute();

    if($res eq undef) {
	die DBI::errstr;
    }
    
    my %config =  map {$_->{'Param'}, $_->{'Value'}} grep { @params == 0 || _in_list($_->{'Param'}, @params) } @{$self->{'config_h'}->fetchall_arrayref({})};
    
    return \%config;
}

sub _in_list {
    my ($value, @list) = @_;


    return 1 if(grep {$_ eq $value} @list);

    return 0;
}

return 1;
