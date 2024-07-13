#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Assuming gpost.pm is in the same directory or accessible via Perl's library path
use gpost;

# Mock environment variables (simulating an HTTP request)
$ENV{'REQUEST_METHOD'} = 'POST';
$ENV{'CONTENT_TYPE'} = 'application/json';
$ENV{'CONTENT_LENGTH'} = 56;  # Length of the JSON data
$ENV{'REQUEST_URI'} = '/example/api';

# Example JSON data (simulating POST data)
my $json_data = '{"username": "john_doe", "password": "s3cr3t"}';

# Initialize the gpost object
my $gpost = gpost::init($ENV{'CONTENT_TYPE'}, $json_data);

# Test initialization
ok(!$gpost->{error}, "Initialization without errors");

# Test decoding JSON data
$gpost->decode_json();
is($gpost->get('username'), 'john_doe', "Decoded JSON data - username");
is($gpost->get('password'), 's3cr3t', "Decoded JSON data - password");

# Test accessing request URI component
is($gpost->request_uri(1), 'example', "Request URI component");

# Test adding and retrieving key-value pairs
$gpost->add('new_key', 'new_value');
is($gpost->get('new_key'), 'new_value', "Add and get key-value pair");

# Test setting a key-value pair
$gpost->set('username', 'updated_username');
is($gpost->get('username'), 'updated_username', "Set and get key-value pair");

# Test checking key existence
ok($gpost->exists('username'), "Check existence of 'username'");

# Test saving and retrieving uploaded file information (mocking an uploaded file)
my $upload_formname = 'file';
my $save_directory = '/tmp';  # Temporary directory for testing
my $file_content = "This is a mock file content.";
$gpost->{upload}{$upload_formname} = {
    length => length($file_content),
    file => 'mock_file.txt'
};

# Test saving an uploaded file
$gpost->save($upload_formname, $save_directory);

# Verify if the file is saved in the specified directory
my $saved_file = "$save_directory/mock_file.txt";
ok(-e $saved_file, "Uploaded file saved successfully");

# Test retrieving uploaded file information
my $file_info = $gpost->uploadedfile($upload_formname);
is($file_info->{file}, 'mock_file.txt', "Retrieved uploaded file information");

# Test non-existent key
is($gpost->get('nonexistent_key'), undef, "Get non-existent key returns undef");

# Test decoding XML data (mock XML data)
$ENV{'CONTENT_TYPE'} = 'application/xml';
my $xml_data = '<root><name>John Doe</name><age>30</age></root>';
$gpost = gpost::init($ENV{'CONTENT_TYPE'}, $xml_data);
$gpost->decode_xml();
is($gpost->get('name'), 'John Doe', "Decoded XML data - name");

# Test decoding MIME multipart form data (mock multipart form data)
$ENV{'CONTENT_TYPE'} = 'multipart/form-data; boundary=---BOUNDARY';
my $multipart_data = <<'MULTIPART';
---BOUNDARY
Content-Disposition: form-data; name="field1"

value1
---BOUNDARY
Content-Disposition: form-data; name="field2"

value2
---BOUNDARY--
MULTIPART

$gpost = gpost::init($ENV{'CONTENT_TYPE'}, $multipart_data);
$gpost->decode_mime();
is($gpost->get('field1'), 'value1', "Decoded MIME multipart form data - field1");

# Test error handling (mocking an unknown content type)
$ENV{'CONTENT_TYPE'} = 'unknown/content-type';
$gpost = gpost::init($ENV{'CONTENT_TYPE'}, '');
is($gpost->{error}, "GPost.init: Unknown Content-type found 'unknown/content-type'", "Error handling - unknown content type");

done_testing();
