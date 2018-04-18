package Outcomes;

use strict;
use DBI;

sub check_result {
    my $res = shift;
	
    if(!defined $res) {
        die DBI::errstr;
    }
}

sub new {
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

    my $this = {
        'dbh' => $dbh,
        'dbname' => $dbname,
        'config_h' => $dbh->prepare("SELECT * FROM oc_config"),
        'category_list_h' => $dbh->prepare("SELECT id, name, description, position FROM oc_categories ORDER BY position, id"),
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

# find user by name
sub get_user_by_name {
   my ($self, $username) = @_;

   my $res = $self->{'select_user_by_name_h'}->execute($username);
   check_result($res);
   my $user = $self->{'select_user_by_name_h'}->fetchrow_hashref();
   return $user;
}


# check user and password
sub check_user {
    my ($self, $username, $passwd) = @_;

    my $user = $self->get_user_by_name($username);
    return 0 if(!defined $user);

    my $sth = $self->{'dbh'}->prepare("SELECT COUNT(*) FROM oc_users WHERE ID=? AND Passwd=PASSWORD(?)");
    $sth->execute($user->{'ID'}, $passwd);
    my $exists = ($sth->fetchrow_array())[0];
    return  $exists ? $user->{'User'} : 0;
}

# gets category list
sub get_category_list {
    my $self = shift;

    my $res = $self->{'category_list_h'}->execute();
    check_result($res);
    return $self->{'category_list_h'}->fetchall_arrayref({});
}

# gets description list
sub get_description_list {
    my $self = shift;

    my $res = $self->{'description_list_h'}->execute();
    check_result($res);
    return $self->{'description_list_h'}->fetchall_arrayref({});
}

# gets years for outcomes
sub get_years {
    my $self = shift;
    
    my $sth = $self->{'dbh'}->prepare("SELECT DISTINCT YEAR(Date) AS year FROM oc_data ORDER BY year DESC");
    my $res = $sth->execute();
    check_result($res);
    return $sth->fetchall_arrayref({});
}

# gets user list
sub get_user_list {
    my $self = shift;
    
    my $res = $self->{'user_list_h'}->execute();
    check_result($res);
    return $self->{'user_list_h'}->fetchall_arrayref({});
}

#returning outcome hash by id
sub get_outcome {
    my ($self, $id) = @_;
    
    my $res = $self->{'select_outcome_h'}->execute($id);
    check_result($res);
    return $self->{'select_outcome_h'}->fetchrow_hashref();
}

# returning category hash by id
sub get_category {
    my ($self, $id) = @_;

    my $res = $self->{'select_category_h'}->execute($id);
    check_result($res);
    return $self->{'select_category_h'}->fetchrow_hashref();
}

# match most common category with given description
sub get_category_for_descr {
    my ($self, $descr) = @_;

    my $res = $self->{'select_category_for_description_h'}->execute($descr);
    check_result($res);
    my @categories = map {$_->[0]} @{$self->{'select_category_for_description_h'}->fetchall_arrayref([0])};
    return \@categories;
}

# @TODO: ???
sub get_category_positions {
    my ($self) = @_;

    my $sth = $self->{'dbh'}->prepare('SELECT Position from oc_categories ORDER BY Position');
    my $res = $sth->execute();
    check_result($res);
    my @positions = map {$_->[0]} @{$sth->fetchall_arrayref([0])};
    return \@positions;
}

# saves new category
sub add_category {
    my ($self, $category) = @_;

    my $sth = $self->{'dbh'}->prepare("UPDATE oc_categories SET Position = Position + 1 WHERE Position >= ?");
    my $res = $sth->execute($category->{'position'});
    check_result($res);

    $res = $self->{'insert_category_h'}->execute(
        $category->{'name'},
        $category->{'description'},
        $category->{'position'},
    );
    check_result($res);
}

# saves existing category hash
sub update_category {
    my ($self, $category) = @_;

    my $c = $self->get_category($category->{'id'});
    $self->{'dbh'}->{AutoCommit} = 0;
    eval {
        if($c->{'position'} != $category->{'position'}) {
            my $sth = $self->{'dbh'}->prepare('UPDATE oc_categories SET Position = Position - 1 WHERE Position > ?');
            my $res = $sth->execute($c->{'Position'});
            check_result($res);
            $sth = $self->{'dbh'}->prepare('UPDATE oc_categories SET Position = Position + 1 WHERE Position >= ?');
            $res = $sth->execute($category->{'position'});
            check_result($res);
        }
        my $res = $self->{'update_category_h'}->execute(
            $category->{'name'},
            $category->{'description'},
            $category->{'position'},
            $category->{'id'}
        );
        check_result($res);
    }; # eval
    my $error = $@;
    if($error) {
        $self->{'dbh'}->rollback;
    } else {
        $self->{'dbh'}->commit;
    }

    die $error if($error);
}

# remove existing category
sub remove_category {
    my ($self, $id) = @_;

    my $c = $self->get_category($id);
    my $res = $self->{'delete_category_h'}->execute($id);
    check_result($res);

    my $sth = $self->{'dbh'}->prepare("UPDATE oc_categories SET Position = Position - 1 WHERE Position >= ?");
    $res = $sth->execute($c->{'Position'});
    check_result($res);
}

# add new outcome
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
    check_result($res);
}

# update existing outcome
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
    check_result($res);
}

# removing existing outcome
sub remove_outcome {
    my ($self, $id) = @_;

    my $res = $self->{'delete_outcome_h'}->execute($id);
    check_result($res);
}

# getting outcomes list
sub get_outcomes_list {
    my ($self, %args) = @_;
    my $year = $args{'year'};
    my $month = $args{'month'};
    my $category = $args{'category'};
    my $user = $args{'user'};
    my $descr = $args{'description'};
    my $discount = $args{'discount'};
    my $date_from = $args{'date_from'};
    my $date_to = $args{'date_to'};
    my $date = (defined $date_from && defined $date_to);

    my $sql = "SELECT D.id, D.date, D.value, D.description, D.details, U.user as author,  C.name AS category, D.discount" .
        " FROM oc_data D" .
        " LEFT JOIN oc_categories C ON(D.categoryID=C.ID)" .
        " LEFT JOIN oc_users U ON(D.UserID=U.ID)" .
        " WHERE 0=0";
    my @sql_params = ();
    if(! $date) {
        $sql .= " AND YEAR(D.date)=?";
        push @sql_params, $year;
        if($month) {
            $sql .= " AND month(D.date)=? ";
            push @sql_params, $month;
        }
    }
    if($category) {
        $sql .= " AND C.id=?";
        push @sql_params, $category;
    }
    if($user) {
        $sql .= " AND U.id=?";
        push @sql_params, $user;
    }
    if(defined $descr && (length $descr > 0)) {
        $sql .= " AND ((lower(D.description) REGEXP lower(?)) or (D.details is not null and lower(D.details) REGEXP lower(?)))";
        push @sql_params, $descr; # for description
        push @sql_params, $descr; # for details
    }
    if(defined $discount) {
        $sql .= " AND D.discount=?";
        push @sql_params, $discount;
    }
    if($date) {
        $sql .= " AND D.date>=? AND D.date<=?";
        push @sql_params, $date_from;
        push @sql_params, $date_to;
    }
    $sql .= " ORDER BY D.date DESC, D.id desc";

    my $select_outcomes = $self->{'dbh'}->prepare($sql);
    my $res = $select_outcomes->execute(@sql_params);
    check_result($res);
    return $select_outcomes->fetchall_arrayref({});
}

sub get_outcomes_list_by_year {
    my $self = shift;
    my $year = shift;

    # @TODO: use get_outcomes_list with proper params: year
    
    my $res = $self->{'select_outcomes_by_year_h'}->execute($year);

    if(!defined $res) {
    die DBI::errstr;
    }

    return $self->{'select_outcomes_by_year_h'}->fetchall_arrayref({});
}

# report: getting by category (param: year)
sub get_outcomes_list_by_category {
    my ($self, $year) = @_;
    # liczba miesiecy
    my $select_month_count = $self->{'dbh'}->prepare(
        "SELECT max(MONTH(d.Date)) - min(MONTH(d.Date)) + 1" . # pomijamy biezacy miesiac
        " FROM oc_data d" .
        " WHERE YEAR(d.Date)=?" .
        " AND NOT d.Discount " .
        " AND d.date < date(concat(year(now()), '-', month(now()), '-01'))"
    );
    my $res = $select_month_count->execute($year);
    check_result($res);
    my $monthCnt = ($select_month_count->fetchrow_array())[0];
    return undef if($monthCnt == 0);

    # suma po kategoriach
    my $sql = 'SELECT c.Name as category, ' .
        '       sum(d.Value)/? as monthly,' .
        '       sum(d.Value) as total' .
        '  FROM `oc_categories` c' .
        '  LEFT JOIN `oc_data` d' .
        '  ON (c.ID = d.CategoryID)' .
        " WHERE YEAR(d.Date) = ?" .
        " AND d.Date < date(concat(year(now()), '-', month(now()), '-01'))" .
        " AND NOT d.Discount " .
        ' group by c.ID';
    my $select_list = $self->{'dbh'}->prepare($sql);
    $res = $select_list->execute($monthCnt, $year);
    check_result($res);
    return $select_list->fetchall_arrayref({});
}

# report: outcomes months (params: year)
sub get_available_months_for_outcomes {
    my ($self, $year) = @_;

    # wybieramy dostepne miesiace z wydatkami
    my $sql = 'SELECT MIN(MONTH(d.Date)) as minMonth, MAX(MONTH(d.Date)) as maxMonth ' .
        ' FROM `oc_data` d' .
        ' WHERE YEAR(d.Date) = ?';
    my $sth = $self->{'dbh'}->prepare($sql);
    my $res = $sth->execute($year);
    check_result($res);
    return $sth->fetchrow_array();
}

# report: outcomes by month (params: year, month)
sub get_outcomes_list_by_month {
    my ($self, $year, $month) = @_;

    # wydatki w podanym miesiacu
    my $sql = 'SELECT' .
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
    check_result($res);
    return $select_month_outcome->fetchall_arrayref({});
}

# resport: total outcomes by month
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
    check_result($res);
    return ($select_sum->fetchrow_array())[0];
}

# checks if category is used
sub is_category_used {
    my ($self, $id) = @_;

    my $sth = $self->{'dbh'}->prepare('SELECT COUNT(*) FROM oc_data WHERE CategoryID=?');
    my $res = $sth->execute($id);
    check_result($res);
    return $sth->fetchrow_array();    
}

# change user password
sub set_password {
    my ($self, $username, $passwd) = @_;

    my $res = $self->{'update_usser_passwd_h'}->execute($passwd, $username);
    check_result($res);
}

# getting config from database
sub get_config {
    my ($self, @params) = @_;

    my $res = $self->{'config_h'}->execute();
    check_result($res);
    my %config =  map {$_->{'Param'}, $_->{'Value'}} grep { @params == 0 || _in_list($_->{'Param'}, @params) } @{$self->{'config_h'}->fetchall_arrayref({})};
    return \%config;
}

# (internal) checks if list contains an element
sub _in_list {
    my ($value, @list) = @_;

    return 1 if(grep {$_ eq $value} @list);

    return 0;
}

return 1;
