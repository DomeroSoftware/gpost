#!/usr/bin/perl
use strict;
use warnings;
use gpost;  # Assuming gpost.pm is in the same directory or accessible via Perl's library path

# Mock environment variables (simulating an HTTP request)
$ENV{'REQUEST_METHOD'} = 'POST';
$ENV{'CONTENT_TYPE'} = 'application/json';
$ENV{'CONTENT_LENGTH'} = 56;  # Length of the JSON data
$ENV{'REQUEST_URI'} = '/example/api';

# Example JSON data (simulating POST data)
my $json_data = '{"username": "john_doe", "password": "s3cr3t"}';

# Initialize the gpost object
my $gpost = gpost::init($ENV{'CONTENT_TYPE'}, $json_data);

# Check for errors during initialization
if ($gpost->{error}) {
    die "Initialization error: $gpost->{error}";
}

# Depending on the request type, decode appropriately
if ($gpost->{type} eq 'json') {
    $gpost->decode_json();
}

# Access parsed data
my $username = $gpost->get('username');
my $password = $gpost->get('password');

# Example of using other methods from gpost module
print "Username: $username\n";
print "Password: $password\n";

# Example of checking if a key exists
if ($gpost->exists('username')) {
    print "Username exists.\n";
}

# Example of saving an uploaded file
my $upload_formname = 'file';
my $save_directory = '/path/to/save';
$gpost->save($upload_formname, $save_directory);

# Example of getting uploaded file information
if ($gpost->uploaded($upload_formname)) {
    my $file_info = $gpost->uploadedfile($upload_formname);
    print "Uploaded file info:\n";
    print "File name: $file_info->{file}\n";
    print "File size: $file_info->{length} bytes\n";
}

# Example of iterating through all key-value pairs
my $key_value_pairs = $gpost->getall();
print "All key-value pairs:\n";
foreach my $pair (@$key_value_pairs) {
    print "$pair->{key}: $pair->{value}\n";
}

# Example of getting the number of values associated with a key
my $num_values = $gpost->num('username');
print "Number of values for 'username': $num_values\n";

# Example of retrieving a component of the request URI
my $uri_component = $gpost->request_uri(2);
print "Request URI component at index 2: $uri_component\n";

# Example of using alias functions
my $ruri_component = $gpost->ruri(1);
print "Request URI component (using alias 'ruri'): $ruri_component\n";

# Example of adding and retrieving key-value pairs
$gpost->add('new_key', 'new_value');
my $new_value = $gpost->get('new_key');
print "Value for 'new_key': $new_value\n";

# Example of setting a key-value pair
$gpost->set('username', 'new_username');
my $updated_username = $gpost->get('username');
print "Updated username: $updated_username\n";

# Example of checking if a key exists (using alias)
if ($gpost->exists('new_key')) {
    print "'new_key' exists.\n";
}

# Example of getting the number of values associated with a key
my $num_values_new = $gpost->num('new_key');
print "Number of values for 'new_key': $num_values_new\n";

# Example of decoding XML data (if content type is XML)
# $gpost->decode_xml();  # Uncomment if content type is XML

# Example of decoding MIME multipart form data (if content type is multipart/form-data)
# $gpost->decode_mime();  # Uncomment if content type is multipart/form-data

# Example of calling a non-existent method
# $gpost->nonexistent_method();  # Uncomment to test error handling

# Clean up and exit
exit;

