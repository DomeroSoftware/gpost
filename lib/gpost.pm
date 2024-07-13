#!/usr/bin/perl

package gpost;

#############################################################################
#                                                                           #
#   Gideon CGI GET POST Engine                                              #
#   (C) 2018 Domero                                                         #
#   ALL RIGHTS RESERVED                                                     #
#                                                                           #
#############################################################################

# Base
use strict;
use warnings;
use Exporter;

# CPAN
use JSON;
use XML::Simple;

# Domero
use gerr qw(error);
use gfio;

our $VERSION = '2.1.3';
our @ISA = qw(Exporter);
our @EXPORT = ();
our @EXPORT_OK = qw();

1;

=head1 NAME

gpost - Module for handling HTTP POST requests in Perl

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);
    $gpost->decode_url();

=head1 DESCRIPTION

The C<gpost> module provides functionalities to handle HTTP POST requests in Perl scripts. It includes methods to initialize, decode, and manipulate data from different content types such as URL-encoded forms, multipart forms, JSON, XML, and more.

=head1 FUNCTIONS

=over 4

=item B<gpost::init($type, $data)>

Initialize the gpost object based on the content type and data provided.

=item B<gpost::request_uri($index)>

Get a component of the request URI.

=item B<gpost::ruri($index)>

Alias for C<request_uri>.

=item B<gpost::uploaded($formname)>

Check if a file was uploaded for a specific form field.

=item B<gpost::uploadedfile($formname)>

Get the uploaded file information for a specific form field.

=item B<gpost::save($formname, $dir, $file)>

Save an uploaded file to the specified directory.

=item B<gpost::add($key, $val)>

Add a key-value pair to the internal storage.

=item B<gpost::set($key, $val)>

Set a key-value pair in the internal storage, replacing any existing values.

=item B<gpost::exist($key)>

Check if a key exists in the internal storage.

=item B<gpost::exists($key)>

Alias for C<exist>.

=item B<gpost::get($key, $nr)>

Get the value(s) associated with a key.

=item B<gpost::getall()>

Get all key-value pairs as a list of hashrefs.

=item B<gpost::num($key)>

Get the number of values associated with a key.

=item B<gpost::decode_url()>

Decode URL-encoded data into key-value pairs.

=item B<gpost::decode_mime()>

Decode MIME multipart form data.

=item B<gpost::decode_json()>

Decode JSON data into key-value pairs.

=item B<gpost::decode_xml()>

Decode XML data into key-value pairs.

=back

=cut

=head1 NAME

gpost::init - Initialize the gpost object for handling HTTP POST requests

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init($type, $data);

=head1 DESCRIPTION

The C<init> function initializes a C<gpost> object to handle HTTP POST requests. It determines the type of content being sent, processes the data accordingly, and prepares the object for further interaction.

=head1 PARAMETERS

=over 4

=item C<$type>

The C<$type> parameter specifies the content type of the HTTP request. It can be one of the following values:

=over 8

=item * C<'get'>

Indicates a GET request where data is passed through the URL.

=item * C<application/x-www-form-urlencoded>

Specifies a URL-encoded form data sent via POST.

=item * C<multipart/form-data>

Indicates multipart form data, typically used for file uploads.

=item * C<text/plain>

Specifies plain text data sent via POST.

=item * C<application/json>

Specifies JSON data sent via POST.

=item * C<application/xml>

Specifies XML data sent via POST.

=back

If the C<$type> is not provided or is unknown, the function defaults to inferring the type from the environment variables, typically in an Apache or similar web server environment.

=item C<$data>

Optional. The C<$data> parameter is the raw data payload of the HTTP request body. It is typically used for POST requests where data is sent in the request body.

=back

=head1 RETURN VALUE

Returns a blessed reference to the initialized C<gpost> object upon success, or sets an error state and returns the object if an unknown content type is encountered.

=head1 EXAMPLES

    # Example 1: Initialize gpost object for a URL-encoded form data
    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);

    # Example 2: Initialize gpost object for multipart form data
    my $gpost = gpost::init('multipart/form-data; boundary=---------------------------1234567890', $post_data);

    # Example 3: Initialize gpost object for JSON data
    my $gpost = gpost::init('application/json', $json_data);

=cut

# Initialization function for the gpost object
sub init {
    my ($type, $data) = @_;
    my $self = {}; 
    bless $self;
    
    $self->{key} = {};
    $self->{upload} = {};
    $self->{fileupload} = 0;
    $self->{error} = 0;
    $self->{errormsg} = "";
    $self->{boundary} = "";
    $self->{data} = "";
    $self->{len} = 0;

    # Determine the type of request (GET or POST)
    if (defined $type) {
        if ($type eq 'get') { 
            $self->{type} = 'url';
        } elsif ($type =~ /application\/x-www-form-urlencoded/i) { 
            $self->{type} = 'url';
        } elsif ($type =~ /multipart\/form-data.*?boundary=\"?([^\"]+)\"?$/i) {
            $self->{boundary} = $1; 
            $self->{type} = 'mime';
        } elsif ($type =~ /text\/plain/i) {
            $self->{type} = 'url';
        } elsif ($type =~ /application\/json/i) {
            $self->{type} = 'json';
        } elsif ($type =~ /application\/xml/i) {
            $self->{type} = 'xml';
        } else {
            print STDOUT $self->{error} = error("GPost.init: Unknown Content-type found '$type'", "return=1");
            return $self;
        }
    }

    if (defined $data) {
        $self->{data} = $data;
    }

    # If the type is not yet defined, infer from the assumed Apache environment
    if (!$self->{type}) {
        $self->{ruri} = [split(/\//, shift(@{[split(/\?/, $ENV{REQUEST_URI})]}))];
        if ($ENV{'REQUEST_METHOD'} =~ /get/i) {
            $self->{data} = $ENV{'QUERY_STRING'};
            $self->{type} = 'url';
        } else {
            read(STDIN, $self->{data}, $ENV{'CONTENT_LENGTH'}) || error("Upload not completed");
            if ($ENV{'CONTENT_TYPE'} =~ /application\/x-www-form-urlencoded/i) {
                $self->{type} = 'url';
            } elsif ($ENV{'CONTENT_TYPE'} =~ /multipart\/form-data.*?boundary=\"?([^\"]+)\"?$/i) {
                $self->{boundary} = $1; 
                $self->{type} = 'mime';
            } elsif ($ENV{'CONTENT_TYPE'} =~ /application\/json/i) {
                $self->{type} = 'json';
            } elsif ($ENV{'CONTENT_TYPE'} =~ /application\/xml/i) {
                $self->{type} = 'xml';
            } else {
                $self->{type} = 'url';
            }
        }
    }

    $self->{len} = length($self->{data});
    if ($self->{error} || (!$self->{len})) { return $self }

    if ($self->{type} eq 'url') {
        $self->decode_url();
    } elsif ($self->{type} eq 'mime') {
        $self->decode_mime();
    } elsif ($self->{type} eq 'json') {
        $self->decode_json();
    } elsif ($self->{type} eq 'xml') {
        $self->decode_xml();
    }

    return $self;
}

=head1 NAME

gpost::request_uri - Retrieve a component of the request URI from the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('get');  # Initialize gpost object
    my @ruri = $gpost->request_uri();  # Retrieve all components of the request URI
    my $component = $gpost->request_uri(1);  # Retrieve a specific component of the request URI

=head1 DESCRIPTION

The C<request_uri> function retrieves components of the request URI stored in the initialized C<gpost> object. This URI typically represents the path and query parameters of the HTTP request.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$index>

Optional. The C<$index> parameter specifies the index of the component in the request URI array to retrieve. If provided, returns the component at the specified index. If omitted, returns the entire array of request URI components.

=back

=head1 RETURN VALUE

If C<$index> is provided, returns the component of the request URI at that index. If no C<$index> is provided, returns an array containing all components of the request URI.

=head1 EXAMPLES

    # Example 1: Retrieve all components of the request URI
    my @ruri = $gpost->request_uri();

    # Example 2: Retrieve the first component of the request URI
    my $component = $gpost->request_uri(0);

=cut

# Function to return a component of the request URI
sub request_uri {
    my ($self, $index) = @_;
    if (defined $index) { return $self->{ruri}[$index] }
    return $self->{ruri};
}

=head1 NAME

gpost::ruri - Alias for the request_uri function in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('get');  # Initialize gpost object
    my @ruri = $gpost->ruri();  # Retrieve all components of the request URI
    my $component = $gpost->ruri(1);  # Retrieve a specific component of the request URI

=head1 DESCRIPTION

The C<ruri> function is an alias for C<request_uri> in the C<gpost> object. It provides a convenient way to retrieve components of the request URI stored in the initialized object.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$index>

Optional. The C<$index> parameter specifies the index of the component in the request URI array to retrieve. If provided, returns the component at the specified index. If omitted, returns the entire array of request URI components.

=back

=head1 RETURN VALUE

If C<$index> is provided, returns the component of the request URI at that index. If no C<$index> is provided, returns an array containing all components of the request URI.

=head1 EXAMPLES

    # Example 1: Retrieve all components of the request URI
    my @ruri = $gpost->ruri();

    # Example 2: Retrieve the first component of the request URI
    my $component = $gpost->ruri(0);

=cut

# Alias for request_uri
sub ruri { return request_uri(@_) }

=head1 NAME

gpost::uploaded - Check if a file was uploaded for a specific form field in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW');  # Initialize gpost object
    if ($gpost->uploaded('file_field')) {
        print "File uploaded for 'file_field'\n";
    } else {
        print "No file uploaded for 'file_field'\n";
    }

=head1 DESCRIPTION

The C<uploaded> function in the C<gpost> object checks whether a file was uploaded for a specific form field during initialization with multipart/form-data.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$formname>

The C<$formname> parameter specifies the name of the form field to check for uploaded files.

=back

=head1 RETURN VALUE

Returns C<1> if a file was uploaded for the specified C<$formname>, otherwise returns C<0>.

=head1 EXAMPLE

    # Example:
    my $is_uploaded = $gpost->uploaded('file_field');
    if ($is_uploaded) {
        print "File uploaded for 'file_field'\n";
    } else {
        print "No file uploaded for 'file_field'\n";
    }

=cut

# Check if a file was uploaded for a specific form field
sub uploaded {
    my ($self, $formname) = @_;
    return $self->{upload}{$formname}{length} ? 1 : 0;
}

=head1 NAME

gpost::uploadedfile - Get the uploaded file information for a specific form field in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW');  # Initialize gpost object
    my $filename = $gpost->uploadedfile('file_field');
    if ($filename) {
        print "Uploaded file name: $filename\n";
    } else {
        print "No file uploaded for 'file_field'\n";
    }

=head1 DESCRIPTION

The C<uploadedfile> function in the C<gpost> object retrieves the uploaded file name for a specific form field during initialization with multipart/form-data.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$formname>

The C<$formname> parameter specifies the name of the form field for which to retrieve the uploaded file information.

=back

=head1 RETURN VALUE

Returns the name of the uploaded file associated with the specified C<$formname>. If no file was uploaded for the form field, returns C<undef>.

=head1 EXAMPLE

    # Example:
    my $filename = $gpost->uploadedfile('file_field');
    if ($filename) {
        print "Uploaded file name: $filename\n";
    } else {
        print "No file uploaded for 'file_field'\n";
    }

=cut

# Get the uploaded file information for a specific form field
sub uploadedfile {
    my ($self, $formname) = @_; 
    return $self->{upload}{$formname}{file};
}

=head1 NAME

gpost::save - Save an uploaded file to the specified directory in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW');  # Initialize gpost object
    $gpost->save('file_field', '/path/to/save');  # Save uploaded file from 'file_field' to /path/to/save directory

=head1 DESCRIPTION

The C<save> function in the C<gpost> object saves an uploaded file from a specific form field to a specified directory.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$formname>

The C<$formname> parameter specifies the name of the form field containing the uploaded file to be saved.

=item C<$dir>

The C<$dir> parameter specifies the directory path where the uploaded file should be saved. If not provided, defaults to the current directory ('.').

=item C<$file>

Optional parameter C<$file> specifies the desired filename to save the uploaded file as. If not provided, the original filename from the form field will be used.

=back

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW');
    $gpost->save('file_field', '/path/to/save', 'custom_filename.txt');

=cut

# Save an uploaded file to the specified directory
sub save {
    my ($self, $formname, $dir, $file) = @_;
    if (!$self->{upload}{$formname}) {
        print STDOUT $self->{error} = error("Upload form-field '$formname' does not exist","return=1"); 
        return;
    }
    if (!$dir) { $dir = "." }
    if (substr($dir, length($dir) - 1, 1) eq '/') { $dir = substr($dir, 0, length($dir) - 1) }
    my $fnm = $file ? "$dir/$file" : "$dir/".$self->{upload}{$formname}{file};
    gfio::create($fnm, $self->get($formname));
}

=head1 NAME

gpost::add - Add a key-value pair to the internal storage of the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);  # Initialize gpost object
    $gpost->add('key1', 'value1');  # Add key-value pair 'key1' => 'value1' to internal storage

=head1 DESCRIPTION

The C<add> function in the C<gpost> object adds a key-value pair to the internal storage, allowing storage and retrieval of form data parameters.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$key>

The C<$key> parameter specifies the key under which the value will be stored.

=item C<$val>

The C<$val> parameter specifies the value to be stored.

=back

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/x-www-form-urlencoded', 'key1=value1&key2=value2');
    $gpost->add('key3', 'value3');

=cut

# Add a key-value pair to the internal storage
sub add {
    my ($self, $key, $val) = @_;
    if (!defined $self->{key}{$key}) {
        $self->{key}{$key} = [ $val ];
    } else {
        push @{$self->{key}{$key}}, $val;
    }
}

=head1 NAME

gpost::set - Set a key-value pair in the internal storage of the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);  # Initialize gpost object
    $gpost->set('key1', 'value1');  # Set key-value pair 'key1' => 'value1' in internal storage

=head1 DESCRIPTION

The C<set> function in the C<gpost> object sets a key-value pair in the internal storage. If a value already exists for the specified key, it will be replaced.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$key>

The C<$key> parameter specifies the key under which the value will be stored.

=item C<$val>

The C<$val> parameter specifies the value to be stored.

=back

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/x-www-form-urlencoded', 'key1=value1&key2=value2');
    $gpost->set('key1', 'new_value');

=cut

# Set a key-value pair in the internal storage, replacing any existing values
sub set {
    my ($self, $key, $val) = @_;
    $self->{key}{$key} = [ $val ];
}

=head1 NAME

gpost::exist - Check if a key exists in the internal storage of the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);  # Initialize gpost object
    if ($gpost->exist('key1')) {
        print "Key 'key1' exists in internal storage.\n";
    } else {
        print "Key 'key1' does not exist in internal storage.\n";
    }

=head1 DESCRIPTION

The C<exist> function in the C<gpost> object checks if a key exists in the internal storage. It returns true (1) if the key exists, otherwise false (0).

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$key>

The C<$key> parameter specifies the key to check for existence in the internal storage.

=back

=head1 RETURN VALUE

Returns true (1) if the key exists in the internal storage, otherwise false (0).

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/x-www-form-urlencoded', 'key1=value1&key2=value2');
    if ($gpost->exist('key1')) {
        print "Key 'key1' exists.\n";
    } else {
        print "Key 'key1' does not exist.\n";
    }

=cut

# Check if a key exists in the internal storage
sub exist {
    my ($self, $key) = @_;
    return ref($self->{key}{$key}) ? 1 : 0;
}

=head1 NAME

gpost::exists - Alias for exist in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);  # Initialize gpost object
    if ($gpost->exists('key1')) {
        print "Key 'key1' exists in internal storage.\n";
    } else {
        print "Key 'key1' does not exist in internal storage.\n";
    }

=head1 DESCRIPTION

The C<exists> function in the C<gpost> object is an alias for C<exist>. It checks if a key exists in the internal storage and returns true (1) if the key exists, otherwise false (0).

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$key>

The C<$key> parameter specifies the key to check for existence in the internal storage.

=back

=head1 RETURN VALUE

Returns true (1) if the key exists in the internal storage, otherwise false (0).

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/x-www-form-urlencoded', 'key1=value1&key2=value2');
    if ($gpost->exists('key1')) {
        print "Key 'key1' exists.\n";
    } else {
        print "Key 'key1' does not exist.\n";
    }

=cut

# Alias for exist
sub exists { my $self = shift; return $self->exist(@_) }

=head1 NAME

gpost::get - Retrieve value(s) associated with a key in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);  # Initialize gpost object
    my $value = $gpost->get('key1');  # Retrieve the value associated with 'key1'

=head1 DESCRIPTION

The C<get> function in the C<gpost> object retrieves the value(s) associated with a specific key from the internal storage.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$key>

The C<$key> parameter specifies the key for which the associated value(s) should be retrieved from the internal storage.

=item C<$nr> (optional)

The C<$nr> parameter, if provided and is a non-negative integer, specifies the index of the value to retrieve when multiple values are associated with the same key.

=back

=head1 RETURN VALUE

Returns the value associated with the specified key. If multiple values exist for the key, and C<$nr> is provided, it returns the value at that index. If C<$nr> is not provided, it returns the first value associated with the key. Returns C<undef> if the key does not exist in the internal storage.

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/x-www-form-urlencoded', 'key1=value1&key1=value2&key2=value3');
    
    my $value1 = $gpost->get('key1');       # Returns 'value1'
    my $value2 = $gpost->get('key1', 1);    # Returns 'value2'
    my $value3 = $gpost->get('key2');       # Returns 'value3'

=cut

# Get the value(s) associated with a key
sub get {
    my ($self, $key, $nr) = @_;
    if ($self->{key}{$key}) {
        if ((defined $nr) && ($nr !~ /[^0-9]/)) { return $self->{key}{$key}[$nr] }
        return $#{$self->{key}{$key}} ? @{$self->{key}{$key}} : $self->{key}{$key}[0];
    }
    return undef;
}

=head1 NAME

gpost::getall - Retrieve all key-value pairs from the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);  # Initialize gpost object
    my $all_pairs = $gpost->getall();  # Retrieve all key-value pairs

=head1 DESCRIPTION

The C<getall> function in the C<gpost> object retrieves all key-value pairs stored internally in the object as a list of hash references.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=back

=head1 RETURN VALUE

Returns a reference to an array containing hash references, where each hash reference represents a key-value pair from the internal storage of the C<gpost> object. Each hash reference contains two keys: C<key> (the key name) and C<value> (the associated value or values, joined by comma if multiple).

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/x-www-form-urlencoded', 'key1=value1&key2=value2');
    my $all_pairs = $gpost->getall();

    # $all_pairs contains:
    # [
    #   { key => 'key1', value => 'value1' },
    #   { key => 'key2', value => 'value2' }
    # ]

=cut

# Get all key-value pairs as a list of hashrefs
sub getall {
    my ($self) = @_;
    my $list = [];
    foreach my $key (keys %{$self->{key}}) {
        my $val = $self->{key}{$key};
        $val = join(", ", @$val) if ref($val) eq 'ARRAY';
        push @$list, { key => $key, value => $val };
    }
    return $list;
}

=head1 NAME

gpost::num - Get the number of values associated with a key in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);  # Initialize gpost object
    my $count = $gpost->num('key');  # Get the number of values associated with 'key'

=head1 DESCRIPTION

The C<num> function in the C<gpost> object retrieves the number of values associated with a specified key from the internal storage of the object.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=item C<$key>

The C<$key> parameter specifies the key for which the number of associated values is to be retrieved.

=back

=head1 RETURN VALUE

Returns an integer representing the number of values associated with the specified C<$key> in the internal storage of the C<gpost> object. If no values are associated with the key, returns 0.

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/x-www-form-urlencoded', 'key=value1&key=value2&key=value3');
    my $count = $gpost->num('key');

    # $count contains: 3

=cut

# Get the number of values associated with a key
sub num {
    my ($self, $key) = @_;
    return 0 + @{$self->{key}{$key}};
}

=head1 NAME

gpost::decode_url - Decode URL-encoded data into key-value pairs in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/x-www-form-urlencoded', $post_data);  # Initialize gpost object
    $gpost->decode_url();  # Decode URL-encoded data

=head1 DESCRIPTION

The C<decode_url> function in the C<gpost> object decodes URL-encoded data from the internal data storage and populates key-value pairs in the object's internal storage.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=back

=head1 RETURN VALUE

This function does not return a value.

=head1 SIDE EFFECTS

Populates the internal key-value storage of the C<gpost> object with decoded URL-encoded data.

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/x-www-form-urlencoded', 'key1=value1&key2=value2');
    $gpost->decode_url();

    # Now, you can retrieve values:
    my $value1 = $gpost->get('key1');  # $value1 contains 'value1'

=cut

# Decode URL-encoded data into key-value pairs
sub decode_url {
    my ($self) = @_;
    if (defined $self->{data}) {
        my @pi = split(/&/, $self->{data});
        foreach my $pe (@pi) {
            my ($ky, $vl) = split(/=/, $pe);
            $vl =~ tr/+/ / if defined $vl;
            $vl =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg if defined $vl;
            $self->add($ky, $vl);
        }
    }
}

=head1 NAME

gpost::decode_mime - Decode MIME multipart form data into key-value pairs and handle file uploads in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('multipart/form-data; boundary=BOUNDARY', $post_data);  # Initialize gpost object
    $gpost->decode_mime();  # Decode MIME multipart form data

=head1 DESCRIPTION

The C<decode_mime> function in the C<gpost> object decodes MIME multipart form data from the internal data storage, populates key-value pairs, and handles file uploads if present.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=back

=head1 RETURN VALUE

This function does not return a value.

=head1 SIDE EFFECTS

Populates the internal key-value storage of the C<gpost> object with decoded MIME multipart form data. Handles file uploads by storing relevant information such as filename, MIME type, and directory path.

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('multipart/form-data; boundary=BOUNDARY', $post_data);
    $gpost->decode_mime();

    # Access uploaded file information:
    if ($gpost->uploaded('file1')) {
        my $filename = $gpost->uploadedfile('file1');
        print "Uploaded file: $filename\n";
    }

=cut

# Decode MIME multipart form data
sub decode_mime {
    my ($self) = @_;
    # Process MIME boundary
    my $bsplit = $self->{boundary};
    $bsplit =~ s/(['()+_,-./:=?])/\\$1/g;

    # Split data into blocks
    my ($parsetext, $exploit) = split(/\-\-$bsplit\-\-[\r|\n]{2}/s, $self->{data});
    if ($exploit) {
        print STDOUT $self->{error} = error("Exploit detected in multipart/form-data! <hr><pre>$exploit</pre>","return=1");
        return;
    }
    my @datablocks = split(/\-\-$bsplit[\r|\n]{2}/s, $parsetext);

    if (!@datablocks) {
        print STDOUT $self->{error} = error("No datablocks found in multipart/form-data","return=1");
        return;
    }

    shift @datablocks;
    foreach my $b (@datablocks) {
        my $info = {};
        while ($b =~ /^Content-(.+)[\r|\n]{2}/i) {
            $b = substr($b, length($1) + 9);
            my $cont = $1;
            my @items = split(/;/, $cont);
            foreach my $i (@items) {
                $i =~ s/^[\s]+//;
                if ($i =~ /^name=\"(.+?)\"/i) {
                    $info->{name} = $1;
                } elsif ($i =~ /^filename=\"(.*?)\"/i) {
                    $info->{filename} = $1;
                } elsif ($i =~ /^Type:\s?(.+)$/i) {
                    $info->{type} = $1;
                } elsif ($i =~ /^charset=(.+)$/i) {
                    $info->{charset} = $1;
                } elsif ($i =~ /^Content-transfer-encoding:\s?(.+)$/i) {
                    $info->{encoding} = $1;
                }
            }
        }

        if ($b !~ /^[\r\n]/ || $b !~ /[\r\n]$/) {
            print STDOUT $self->{error} = error("Illegal datablock found in block '<br><pre>$b</pre>","return=1");
            return;
        }

        $b =~ s/[\r|\n]{2}(.+)[\r|\n]{2}/$1/gs;
        push @{$self->{key}->{$info->{name}}}, $b;

        if ($info->{filename}) {
            $self->{fileupload} = 1;
            my $name = $info->{name};
            $self->{upload}{$name} = {
                length => length($b),
                mime => $info->{type},
            };
            my $path = $info->{filename};
            $path =~ s/[*?]//g;
            $path =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
            $path =~ s/ /_/g;
            $path =~ s/\\/\//g;
            $self->{upload}{$name}{dirfile} = $path;
            my @spath = split(/\//, $path); 
            my $file = pop @spath;
            $self->{upload}{$name}{file} = $file;
            $self->{upload}{$name}{dir} = join("/", @spath);
            my ($rf, $ext) = split(/\./, $file);
            $self->{upload}{$name}{filename} = $rf;
            $self->{upload}{$name}{ext} = $ext;
        }
    }
}

=head1 NAME

gpost::decode_json - Decode JSON data into key-value pairs in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/json', $json_data);  # Initialize gpost object
    $gpost->decode_json();  # Decode JSON data

=head1 DESCRIPTION

The C<decode_json> function in the C<gpost> object decodes JSON data from the internal data storage into key-value pairs.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=back

=head1 RETURN VALUE

This function does not return a value.

=head1 SIDE EFFECTS

Populates the internal key-value storage of the C<gpost> object with decoded JSON data. Handles JSON decoding errors and sets an error message if decoding fails.

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/json', $json_data);
    $gpost->decode_json();

    # Access decoded JSON data:
    my $value = $gpost->get('key');

=cut

# Decode JSON data
sub decode_json {
    my ($self) = @_;
    $::EVALMODE++ if (defined $::EVALMODE);
    eval {
        my $decoded_data = decode_json($self->{data});
        foreach my $key (keys %$decoded_data) {
            $self->add($key, $decoded_data->{$key});
        }
    };
    $::EVALMODE-- if (defined $::EVALMODE);
    if ($@) {
        print STDOUT $self->{error} = error("GPost.init: JSON decoding error: $@", "return=1");
    }
}

=head1 NAME

gpost::decode_xml - Decode XML data into key-value pairs in the gpost object

=head1 SYNOPSIS

    use gpost;

    my $gpost = gpost::init('application/xml', $xml_data);  # Initialize gpost object
    $gpost->decode_xml();  # Decode XML data

=head1 DESCRIPTION

The C<decode_xml> function in the C<gpost> object decodes XML data from the internal data storage into key-value pairs.

=head1 PARAMETERS

=over 4

=item C<$self>

The C<$self> parameter is the reference to the C<gpost> object initialized using C<gpost::init()>.

=back

=head1 RETURN VALUE

This function does not return a value.

=head1 SIDE EFFECTS

Populates the internal key-value storage of the C<gpost> object with decoded XML data. Handles XML parsing errors and sets an error message if decoding fails.

=head1 EXAMPLE

    # Example:
    my $gpost = gpost::init('application/xml', $xml_data);
    $gpost->decode_xml();

    # Access decoded XML data:
    my $value = $gpost->get('key');

=cut

# Decode XML data
sub decode_xml {
    my ($self) = @_;
    $::EVALMODE++ if (defined $::EVALMODE);
    eval {
        my $decoded_data = XMLin($self->{data});
        foreach my $key (keys %$decoded_data) {
            $self->add($key, $decoded_data->{$key});
        }
    };
    $::EVALMODE-- if (defined $::EVALMODE);
    if ($@) {
        print STDOUT $self->{error} = error("GPost.init: XML decoding error: $@", "return=1");
    }
}

=head1 SEE ALSO

L<JSON>, L<XML::Simple>, L<gfio>, L<gerr>

=head1 AUTHOR

Domero Software <domerosoftware@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Domero Software

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 DISCLAIMER

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

# End of file gpost.pm (C) 2018 Domero
