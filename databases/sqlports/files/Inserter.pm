#! /usr/bin/perl
# $OpenBSD: Inserter.pm,v 1.21 2018/11/27 10:36:17 espie Exp $
#
# Copyright (c) 2006-2010 Marc Espie <espie@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;

package Composite;
sub AUTOLOAD
{
	our $AUTOLOAD;
	my $fullsub = $AUTOLOAD;
	(my $sub = $fullsub) =~ s/.*:://o;
	return if $sub eq 'DESTROY'; # special case
	my $self = $_[0];
	# verify it makes sense
	if ($self->element_class->can($sub)) {
		no strict "refs";
		# create the sub to avoid regenerating further calls
		*$fullsub = sub {
			my $self = shift;
			$self->visit($sub, @_);
		};
		# and jump to it
		goto &$fullsub;
	} else {
		die "Can't call $sub on ".ref($self);
	}
}


package InserterList;
our @ISA = qw(Composite);
sub element_class() { 'NormalInserter' }

sub new
{
	my $class = shift;
	bless [], $class;
}

sub add
{
	my $self = shift;
	push(@$self, @_);
}

sub visit
{
	my ($self, $method, @r) = @_;
	for my $i (@$self) {
		$i->$method(@r);
	}
}

package AbstractInserter;
# this is the object to use to put stuff into the db...
sub new
{
	my ($class, $db, $i, $verbose) = @_;
	$db->do("PRAGMA foreign_keys=ON");
	bless {
		db => $db,
		transaction => 0,
		threshold => $i,
		vars => {},
		table_created => {},
		view_created => {},
		errors => [],
		done => {},
		todo => {},
		verbose => $verbose,
	}, $class;
}

sub add_error
{
}

sub table_name
{
	my ($class, $name) = @_;
	return $name;
}

sub view_name
{
	my ($class, $name) = @_;
	return $name;
}

sub write_log
{
}

sub current_path
{
	my $self = shift;
	return $self->{current_path};
}

sub set_newkey
{
	my ($self, $key) = @_;
	$self->{current_path} = $key;
}

sub create_tables
{
	my ($self, $vars) = @_;

	$self->create_path_table;
	# XXX sort it
	for my $t (sort keys %$vars) {
		$vars->{$t}->prepare_tables($self, $t);
	}

	$self->create_ports_table;
	$self->prepare_normal_inserter('Ports', @{$self->{varlist}});
	$self->prepare_normal_inserter('Paths', 'PKGPATH', 'CANONICAL');
	$self->create_view_info;
	$self->commit_to_db;
	print '-'x50, "\n" if $self->{verbose};
}

sub handle_column
{
	my ($self, $column) = @_;
	push(@{$self->{varlist}}, $column->{name});
	push(@{$self->{columnlist}}, $column);
}

sub create_view_info
{
}

sub map_columns
{
	my ($self, $mapper, $colref, @p) = @_;
	$mapper .= '_schema';
	return grep {defined $_} (map {$_->$mapper(@p)} @$colref);
}

sub make_table
{
	my ($self, $class, $constraint, @columns) = @_;

	unshift(@columns, PathColumn->new);
	for my $c (@columns) {
		$c->set_vartype($class) unless defined $c->{vartype};
	}
	my @l = $self->map_columns('normal', \@columns, $self);
	push(@l, $constraint) if defined $constraint;
	$self->new_table($class->table, @l);
}

sub subselect
{
	my ($self, $class) = @_;
	return $class->subselect($self);
}

sub make_ordered_view
{
	my ($self, $class) = @_;

	my $view = $self->view_name($class->table."_ordered");
	my $subselect = $self->subselect($class);
	my @group = $class->group_by;
	unshift(@group, 'fullpkgpath');
	my $groupby = join(', ', @group);
	my $result = join(',', @group, 'group_concat(value, " ") as value');
	$self->new_object('VIEW', $class->table."_ordered",
	    qq{as 
	    	with o as ($subselect)
	    select $result from o group by $groupby;});
}

sub set
{
	my ($self, $ref) = @_;
	$self->{ref} = $ref;
}

sub db
{
	return shift->{db};
}

sub last_id
{
	return shift->db->func('last_insert_rowid');
}

sub insert_done
{
	my $self = shift;
	$self->{transaction}++;
}

sub new_object
{
	my ($self, $type, $name, $request) = @_;
	my $o;
	if ($type eq 'VIEW') {
		return if defined $self->{view_created}{$name};
		$self->{view_created}{$name} = 1;
		$o = $self->view_name($name);
	} elsif ($type eq 'TABLE') {
		return if defined $self->{table_created}{$name};
		$self->{table_created}{$name} = 1;
		$o = $self->table_name($name);
	} else {
		die "unknown object type";
	}
	$self->db->do("DROP $type IF EXISTS $o");
	$request = "CREATE $type $o $request";
	print "$request\n" if $self->{verbose};
	$self->db->do($request);
}

sub new_table
{
	my ($self, $name, @cols) = @_;

	$self->new_object('TABLE', $name, "(".join(', ', @cols).")");
}

sub prepare
{
	my ($self, $s) = @_;
	return $self->db->prepare($s);
}

sub prepare_inserter
{
	my ($ins, $table, @cols) = @_;
	$ins->{insert}{$table} = $ins->prepare(
	    "INSERT OR REPLACE INTO ".
	    $ins->table_name($table)." (".
	    join(', ', @cols).
	    ") VALUES (".
	    join(', ', map {'?'} @cols).")");
}

sub prepare_normal_inserter
{
	my ($ins, $table, @cols) = @_;
	$ins->prepare_inserter($table, "FULLPKGPATH", @cols);
}

sub finish_port
{
	my $self = shift;
	my @values = ($self->ref);
	for my $i (@{$self->{varlist}}) {
		push(@values, $self->{vars}->{$i});
	}
	$self->insert('Ports', @values);
	$self->{vars} = {};
	if ($self->{transaction} >= $self->{threshold}) {
		$self->commit_to_db;
		$self->{transaction} = 0;
	}
}

sub add_to_port
{
	my ($self, $var, $value) = @_;
	$self->{vars}{$var} = $value;
}

sub create_ports_table
{
	my $self = shift;

	my @columns = sort {$a->name cmp $b->name} @{$self->{columnlist}};
	unshift(@columns, PathColumn->new);
	my @l = $self->map_columns('normal', \@columns, $self);
	$self->new_table("Ports", @l, "UNIQUE(FULLPKGPATH)");
}

sub ref
{
	return shift->{ref};
}

sub insert
{
	my $self = shift;
	my $table = shift;
	$self->{insert}{$table}->execute(@_);
	$self->insert_done;
}

sub add_var
{
	my ($self, $v) = @_;
	$v->add($self);
}

sub id
{
	return 'fullpkgpath';
}

sub create_canonical_depends
{
	my ($self, $class) = @_;
	my $t = $class->table;
	my $id = $self->id;
	my $p = $self->table_name("Paths");
	$self->new_object('VIEW', "canonical_depends",
		qq{as select 
		    p1.canonical as fullpkgpath, 
		    p2.canonical as dependspath, $t.type from $t 
		join $p p1 on p1.$id=$t.fullpkgpath
		join $p p2 on p2.$id=$t.dependspath});
}

sub commit_to_db
{
	my $self = shift;
	$self->db->commit;
}

package CompactInserter;
our @ISA = qw(AbstractInserter);

our $c = {
	Library => 0,
	Run => 1,
	Build => 2,
	Test => 3
};

sub table_name
{
	my ($class, $name) = @_;
	return $name;
}

sub view_name
{
	my ($class, $name) = @_;
	return "_$name";
}

sub subselect
{
	my ($self, $class) = @_;
	return $class->subselect_compact($self);
}

sub convert_depends
{
	my ($self, $value) = @_;
	return $c->{$value};
}


sub pathref
{
	my ($self, $name) = @_;
	$name = "FULLPKGPATH" if !defined $name;
	return "$name INTEGER NOT NULL REFERENCES ".
	    $self->table_name("Paths")."(ID)";
}

sub id
{
	return 'Id';
}

sub value
{
	my ($self, $k, $name) = @_;
	$name = "VALUE" if !defined $name;
	if (defined $k) {
		return "$name INTEGER NOT NULL REFERENCES ".
		    $self->table_name($k)."(KEYREF)";
	} else {
		return "$name TEXT NOT NULL";
	}
}

sub optvalue
{
	my ($self, $k, $name) = @_;
	$name = "VALUE" if !defined $name;
	if (defined $k) {
		return "$name INTEGER REFERENCES ".
		    $self->table_name($k)."(KEYREF)";
	} else {
		return "$name TEXT";
	}
}

sub create_view
{
	my ($self, $table, @columns) = @_;

	unshift(@columns, PathColumn->new);
	my $t = $self->table_name($table);
	my @l = $self->map_columns('view', \@columns, $t, $self);
	my @j = $self->map_columns('join', \@columns, $t, $self);
	$self->new_object('VIEW', $table,
	    "AS SELECT ".join(", ", @l). " FROM ".
	    $t.' '.join(' ', @j));
}

sub make_table
{
	my ($self, $class, $constraint, @columns) = @_;

	$self->SUPER::make_table($class, $constraint, @columns);
	$self->create_view($class->table, @columns);
}

sub create_path_table
{
	my $self = shift;
	$self->new_table("Paths", "ID INTEGER PRIMARY KEY",
	    "FULLPKGPATH TEXT NOT NULL UNIQUE",
	    $self->pathref("PKGPATH"), $self->pathref("CANONICAL"));
	$self->{adjust} = $self->db->prepare("UPDATE ".
	    $self->table_name("Paths")." set canonical=? where id=?");
}

sub handle_column
{
	my ($self, $column) = @_;
	if ($column->{vartype}->want_in_ports_view) {
		$self->SUPER::handle_column($column);
	}
}

sub create_view_info
{
	my $self = shift;
	my @columns = sort {$a->name cmp $b->name} @{$self->{columnlist}};
	$self->create_view("Ports", @columns);
}

my $path_cache = {};
my $newid = 1;
sub find_pathkey
{
	my ($self, $key) = @_;

	if (!defined $key or $key eq '') {
		print STDERR "Empty pathkey\n";
		return 0;
	}
	if (defined $path_cache->{$key}) {
		return $path_cache->{$key};
	}

	# if none, we create one
	my $path = $key;
	$path =~ s/\,.*//;
	if ($path ne $key) {
		$path = $self->find_pathkey($path);
	} else {
		$path = $newid;
	}
	$self->insert('Paths', $key, $path, $newid);
	my $r = $self->last_id;
	$path_cache->{$key} = $r;
	$newid++;
	return $r;
}

sub add_path
{
	my ($self, $key, $alias) = @_;
	$self->{adjust}->execute($path_cache->{$alias}, $path_cache->{$key});
}

sub set_newkey
{
	my ($self, $key) = @_;

	$self->set($self->find_pathkey($key));
	$self->SUPER::set_newkey($key);
}

sub find_keyword_id
{
	my ($self, $key, $t) = @_;
	$self->{$t}{find_key1}->execute($key);
	my $a = $self->{$t}{find_key1}->fetchrow_arrayref;
	if (!defined $a) {
		$self->{$t}{find_key2}->execute($key);
		$self->insert_done;
		return $self->last_id;
	} else {
		return $a->[0];
	}
}

sub create_keyword_table
{
	my ($self, $t) = @_;
	my $name = $self->table_name($t);
	$self->new_table($t,
	    "KEYREF INTEGER PRIMARY KEY AUTOINCREMENT",
	    "VALUE TEXT NOT NULL UNIQUE");
	$self->{$t}{find_key1} = $self->prepare("SELECT KEYREF FROM $name WHERE VALUE=?");
	$self->{$t}{find_key2} = $self->prepare("INSERT INTO $name (VALUE) VALUES (?)");
}

sub write_log
{
}

package NormalInserter;
our @ISA = qw(AbstractInserter);

our $c = {
	Library => 'L',
	Run => 'R',
	Build => 'B',
	Test => 'T'
};

sub add_error
{
	my ($self, $msg) = @_;
	push(@{$self->{errors}}, $msg);
}

sub write_log
{
	my ($self, $log) = @_;

	foreach my $error (@{$self->{errors}}) {
		print $log $error."\n";
	}
}

sub convert_depends
{
	my ($self, $value) = @_;
	return $c->{$value};
}

sub create_path_table
{
	my $self = shift;
	$self->new_table("Paths", "FULLPKGPATH TEXT NOT NULL PRIMARY KEY",
	    $self->pathref("PKGPATH"), $self->pathref("CANONICAL"));
}

sub pathref
{
	my ($self, $name) = @_;
	$name = "FULLPKGPATH" if !defined $name;
	return "$name TEXT NOT NULL";
}

sub value
{
	my ($self, $k, $name) = @_;
	$name = "VALUE" if !defined $name;
	return "$name TEXT NOT NULL";
}

sub optvalue
{
	my ($self, $k, $name) = @_;
	$name = "VALUE" if !defined $name;
	return "$name TEXT";
}

sub key
{
	return "TEXT NOT NULL";
}

sub optkey
{
	return "TEXT";
}

sub set_newkey
{
	my ($self, $key) = @_;

	$self->SUPER::set_newkey($key);
	my $path = $key;
	$path =~ s/\,.*//;
	$self->insert('Paths', $key, $path, $key);
	$self->set($key);
}

sub add_path
{
	my ($self, $key, $alias) = @_;
	my $path = $key;
	$path =~ s/\,.*//;
	$self->insert('Paths', $key, $path, $alias);
}

sub find_pathkey
{
	my ($self, $key) = @_;

	return $key;
}

# no keyword for this dude
sub find_keyword_id
{
	my ($self, $key, $t) = @_;
	return $key;
}

sub create_keyword_table
{
}

1;
