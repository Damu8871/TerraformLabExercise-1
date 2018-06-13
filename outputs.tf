output "elb_dnsname" {
	value = "${aws_elb.apache_php_elb.dns_name}"
}
