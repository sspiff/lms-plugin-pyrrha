package Crypt::ECB;

# Copyright (C) 2000, 2005, 2008, 2016 Christoph Appel (Christoph.Appel@t-systems.com)
#  see documentation for details


########################################
# general module startup things
########################################

use strict;
use warnings;

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

require Exporter;

@ISA       = qw(Exporter);
@EXPORT_OK = qw(encrypt decrypt encrypt_hex decrypt_hex);
$VERSION   = '2.23';


########################################
# public methods - setting up
########################################

#
# constructor, initialization of vars
#
sub new ($;$$$)
{
	my $class = shift;

	my $self =
	{
		padding		=> 'standard', # default padding method
		mode		=> '',
		key		=> '',
		cipher		=> '',
		module		=> '',
		keysize		=> '',
		blocksize	=> '',

		_cipherobj	=> '', # contains the block cipher object
		_buffer		=> '', # internal buffer used by crypt() and finish()
	};

	bless $self, $class;

	if ($_[0])
	{
		my $options;

		# options Crypt::CBC style
		if ($_[0] =~ /^-[a-zA-Z]+$/)
		{
			my %tmp = @_;
			$options->{substr(lc $_, 1)} = $tmp{$_} for keys %tmp;
		}

		# options like in Crypt::CBC before 2.13
		elsif (ref $_[0] eq 'HASH')
		{
			$options = shift;
		}	

		# and like Crypt::CBC before 2.0
		else
		{
			$options->{key}    = shift;
			$options->{cipher} = shift || 'DES';
		}

		# cipher has to be called before keysize and blocksize
		# otherwise it would override values provided by the user
		$self->$_( $options->{$_} ) foreach qw(cipher keysize key blocksize padding);
	}

	return $self;
}

#
# set attributes if argument given, return attribute value
#
sub module	(\$)	{					return $_[0]->{module}    }
sub keysize	(\$;$)	{ $_[0]->{keysize}   = $_[1] if $_[1];	return $_[0]->{keysize}   }
sub blocksize	(\$;$)	{ $_[0]->{blocksize} = $_[1] if $_[1];	return $_[0]->{blocksize} }
sub mode	(\$)	{ 					return $_[0]->{mode}      }

#
# sets key if argument given
#
sub key (\$;$)
{
	my $self = shift;

	if (my $key = shift)
	{
		$self->{key} = $key;

		# forget cipher object to force creating a new one
		# otherwise a key change would not be recognized
		$self->{_cipherobj} = '';
	}

	return $self->{key};
}

#
# sets padding method if argument given
#
sub padding (\$;$)
{
	my $self = shift;

	if (my $padding = shift)
	{
		# if given a custom padding...
		if (ref $padding eq 'CODE')
		{
			# ...for different block sizes...
			for my $bs ((8, 16))
			{
				# ...check whether it works as expected
				for my $i (0 .. $bs-1)
				{
					my $plain = ' ' x $i;

					my $padded = $padding->($plain, $bs, 'e') || '';
					die "Provided padding method does not pad properly: Expected $bs bytes, got ", length $padded, ".\n"
						unless (length $padded == $bs);

					my $trunc = $padding->($padded, $bs, 'd') || '';
					die "Provided padding method does not truncate properly: Expected '$plain', got '$trunc'.\n"
						unless ($trunc eq $plain);
				}
			}
		}

		$self->{padding} = $padding;
	}

	return $self->{padding};
}

#
# sets and loads crypting module if argument given
#
sub cipher (\$;$)
{
	my $self = shift;

	if (my $cipher = shift)
	{
		my $module;

		# if a cipher object is provided...
		if (ref $cipher)
		{
			# ...use it
			$self->{_cipherobj} = $cipher;

			$module = ref $cipher;
			($cipher = $module) =~ s/^Crypt:://;
		}

		# else try to load the specified cipher module
		else
		{
			# for compatibility with Crypt::CBC, cipher modules can be specified
			# with or without the 'Crypt::' in front
			$module = $cipher=~/^Crypt/ ? $cipher : "Crypt::$cipher";

			eval "require $module";
			die "Couldn't load $module: $@"."Are you sure '$cipher' is correct? If so,"
			  . " install $module in the proper path or choose some other cipher.\n"
				if $@;

			# delete possibly existing cipher obj from a previous crypt process
			# otherwise changes in the cipher would not be recognized by start()
			$self->{_cipherobj} = '';
		}

		# some packages like Crypt::DES and Crypt::IDEA behave strange in the way
		# that their methods do not belong to the Crypt::DES or Crypt::IDEA namespace
		# but only DES or IDEA instead
		unless ($module->can('blocksize')) { $module=$cipher }

		die "Can't work because Crypt::$cipher doesn't report blocksize."
		  . " Are you sure $cipher is a valid cipher module?\n"
			unless ($module->can('blocksize') && $module->blocksize);

		$self->{blocksize} = $module->blocksize;

		# In opposition to the blocksize, the keysize need not be known by me,
		# but by the one who provides the key. This is because some modules
		# (e.g. Crypt::Blowfish) report keysize 0; in other cases several keysizes
		# are admitted, so reporting just one number would anyway be to narrow
		$self->{keysize} = $module->can('keysize') ? $module->keysize : '';

		$self->{module} = $module;
		$self->{cipher} = $cipher;
	}

	return $self->{cipher};
}


########################################
# public methods - en-/decryption
########################################

#
# sets mode if argument given, either en- or decrypt
# checks, whether all required vars are set
# returns mode
#
sub start (\$$)
{
	my $self = shift;
	my $mode = shift;

	die "Not yet finished existing crypting process. Call finish() before calling start() anew.\n"
		if $self->{_buffer};

	die "Mode has to be either (e)ncrypt or (d)ecrypt.\n"
		unless ($mode=~/^[de]/i);

	# unless a cipher object is provided (see cipher())...
	unless ($self->{_cipherobj})
	{
		# make sure we have a key...
		die "Key not set. Use '\$ecb->key ('some_key'). The key length is probably specified"
		  . " by the algorithm (for example the Crypt::IDEA module needs a sixteen byte key).\n"
			unless $self->{key};

		# ...as well as a block cipher
		die "Can't start() without cipher. Use '\$ecb->cipher(\$cipher)', \$cipher being some"
		  . "  algorithm like for example 'DES', 'IDEA' or 'Blowfish'. Of course, the corresponding"
		  . "  module 'Crypt::\$cipher' needs to be installed.\n"
			unless $self->{module};

		# initialize cipher obj doing the actual en-/decryption
		$self->{_cipherobj} = $self->{module}->new( $self->{key} );
	}

	$self->{mode} = ($mode=~/^d/i) ? "decrypt" : "encrypt";

	return $self->{mode};
}

#
# calls the crypting module
# returns the en-/decrypted data
#
sub crypt (\$;$)
{
	my $self = shift;
	my $data = shift;
    
	$data = ($_ || '') unless defined $data;

	my $bs     = $self->{blocksize};
	my $mode   = $self->{mode};

	die "You tried to use crypt() without calling start() before. Use '\$ecb->start(\$mode)'"
	  . " first, \$mode being one of 'decrypt' or 'encrypt'.\n"
		unless $mode;

	$data = $self->{_buffer}.$data;

	# data is split into blocks of proper size which is reported
	# by the cipher module
	my @blocks = $data=~/(.{1,$bs})/gs;

	# last block goes into buffer
	$self->{_buffer} = pop @blocks;

	my ($cipher, $text) = ($self->{_cipherobj}, '');
	$text .= $cipher->$mode($_) foreach (@blocks);
	return $text;
}

#
#
#
sub finish (\$)
{
	my $self = shift;

	my $bs     = $self->{blocksize};
	my $mode   = $self->{mode};
	my $data   = $self->{_buffer};
	my $result = '';

	die "You tried to use finish() without calling start() before. Use '\$ecb->start(\$mode)'"
	  . " first, \$mode being one of 'decrypt' or 'encrypt'.\n"
		unless $mode;

	# cleanup: forget mode, purge buffer
	$self->{mode}		= '';
	$self->{_buffer}	= '';

	return '' unless defined $data;

	my $cipher = $self->{_cipherobj};

	# now we have to distinguish between en- and decryption:
	# when decrypting, data has to be truncated to correct size
	# when encrypting, data has to be padded up to blocksize
	if ($mode =~ /^d/i)
	{
		# pad data with binary 0 up to blocksize
		# in fact, this should not be necessary because correctly
		# encrypted data is always a multiple of the blocksize
		$data = pack("a$bs",$data);

		$result = $cipher->$mode($data);
		$result = $self->_truncate($result);
	}
	else
	{
		# if length is smaller than blocksize, just pad the block
		if (length($data) < $bs)
		{
			$data = $self->_pad($data);
			$result = $cipher->$mode($data);
		}
		# else append another block (depending on padding chosen)
		else
		{
			$result = $cipher->$mode($data);
			$self->_pad('') &&
				($result .= $cipher->$mode( $self->_pad('') ));
		}
	}

	return $result;
}


########################################
# private methods
########################################

#
# pad block to blocksize
#
sub _pad (\$$)
{
	my $self = shift;
	my $data = shift;

	my $bs      = $self->{blocksize};
	my $padding = $self->{padding};

	my $pad = $bs - length $data;

	my $message = "Your message length is not a multiple of $self->{cipher}'s blocksize ($bs bytes)."
		    . " Correct this by hand or tell me to handle padding.\n";

	$padding eq 'standard' ?	$data .= chr($pad) x  $pad				:
	$padding eq 'zeroes' ?		$data .=      "\0" x ($pad-1) . chr($pad)		:
	$padding eq 'oneandzeroes' ?	                   $data .= "\x80" . "\0"x($pad-1)	:
	$padding eq 'rijndael_compat' ?	(length $data) && ($data .= "\x80" . "\0"x($pad-1))	:
	$padding eq 'null' ?		                   $data .=          "\0"x $pad		:
	$padding eq 'space' ?		(length $data) && ($data .=          " " x $pad)	:
	ref $padding eq 'CODE' ?	$data = $padding ->($data, $bs, 'e')			:
	$padding eq 'none' ?		(length($data) % $bs) && die $message			:

	# still here?
	die "Padding style '$padding' not defined.\n";

	return $data;
}

#
# truncates result to correct length
#
sub _truncate (\$$)
{
	my $self = shift;
	my $data = shift;

	my $bs      = $self->{blocksize};
	my $padding = $self->{padding};

	if ($padding =~ /^(standard|zeroes|random)$/)
	{
		my $trunc = ord(substr $data, -1);

		die "Asked to truncate $trunc bytes, which is greater than $self->{cipher}'s blocksize ($bs bytes).\n"
			if $trunc > $bs;

		my $expected =	$padding eq 'standard' ?	chr($trunc) x  $trunc			:
				$padding eq 'zeroes' ?		       "\0" x ($trunc-1) . chr($trunc)	:
				$padding eq 'random' ?	substr($data, -$trunc, $trunc-1) . chr($trunc)	: 'WTF!?';

		die "Block doesn't look $padding padded.\n" unless $expected eq substr($data, -$trunc);

		substr($data, -$trunc) = '';
	}
	else
	{
		$padding eq 'oneandzeroes' ?	$data =~ s/\x80\0*$//s			:
		$padding eq 'rijndael_compat' ?	$data =~ s/\x80\0*$//s			:
		$padding eq 'null' ?		$data =~ s/\0+$//s			:
		$padding eq 'space' ?		$data =~ s/ +$//s			:
		ref $padding eq 'CODE' ?	$data = $padding->($data, $bs, 'd')	:
		$padding eq 'none' ?		()					:

		# still here?
		die "Padding style '$padding' not defined.\n";
	}

	return $data;
}


########################################
# convenience functions/methods
########################################

#
# magic decrypt/encrypt function/method
#
sub _crypt
{
	my ($mode, $self, $key, $cipher, $data, $padding);

	if (ref $_[1])
	{
		($mode, $self, $data) = @_;
	}
	else
	{
		($mode, $key, $cipher, $data, $padding) = @_;

		$self = __PACKAGE__->new($key => $cipher);
		$self->padding($padding) if $padding;

		$data = $_ unless length($data);
	}

	$self->start($mode);
	my $text = $self->crypt($data) . $self->finish;

	return $text;
}

#
# convenience encrypt and decrypt functions/methods
#
sub encrypt ($$;$$) { _crypt('encrypt', @_) }
sub decrypt ($$;$$) { _crypt('decrypt', @_) }

#
# calls encrypt, returns hex packed data
#
sub encrypt_hex ($$;$$)
{
	if (ref $_[0])
	{
		my $self = shift;
		join('',unpack('H*',$self->encrypt(shift)));
	}
	else
	{
		join('',unpack('H*',encrypt($_[0], $_[1], $_[2], $_[3])));
	}
}

#
# calls decrypt, expected input is hex packed
#
sub decrypt_hex ($$;$$)
{
	if (ref $_[0])
	{
		my $self = shift;
		$self->decrypt(pack('H*',shift));
	}
	else
	{
		decrypt($_[0], $_[1], pack('H*',$_[2]), $_[3]);
	}
}


########################################
# finally, to satisfy require
########################################

'The End...';
__END__


=head1 NAME

Crypt::ECB - Use block ciphers using ECB mode

=head1 SYNOPSIS

Use Crypt::ECB OO style

  use Crypt::ECB;

  $ecb = Crypt::ECB->new;
  $ecb->cipher('Blowfish');
  $ecb->key('some_key'); 

  $enc = $ecb->encrypt("Some data.");
  print $ecb->decrypt($enc);

or use the function style interface

  use Crypt::ECB qw(encrypt decrypt encrypt_hex decrypt_hex);

  $ciphertext = encrypt($key, 'Blowfish', "Some data");
  $plaintext  = decrypt($key, 'Blowfish', $ciphertext);

  $hexcode = encrypt_hex($key, $cipher, $plaintext);
  $plain   = decrypt_hex($key, $cipher, $hexcode);

=head1 DESCRIPTION

This module is a Perl-only implementation of the ECB mode. In
combination with a block cipher such as Blowfish, DES, IDEA or Rijndael,
you can encrypt and decrypt messages of arbitrarily long length. Though
for security reasons other modes than ECB such as CBC should be
preferred. See textbooks on cryptography if you want to know why.

The functionality of the module can be accessed via OO methods or via
standard function calls. Remember that some block cipher module like for
example Crypt::Blowfish has to be installed. The syntax of Crypt::ECB
follows that of Crypt::CBC.

=head1 METHODS

=head2 new()

  $ecb = Crypt::ECB->new(
	-cipher    => $cipher,
	-key       => $key,
	-padding   => 'oneandzeroes',
	-keysize   => 8,  # use to override cipher's default
	-blocksize => 8,  # use to override cipher's default
  );

or

  $ecb = Crypt::ECB->new({
	cipher    => $cipher,
	key       => $key,
	padding   => 'oneandzeroes',
	keysize   => 8,  # use to override cipher's default
	blocksize => 8,  # use to override cipher's default
  });

or (only key and cipher can be passed this way)

  $ecb = Crypt::ECB->new($key, 'Blowfish');
  $ecb = Crypt::ECB->new($key);	# DES is assumed

The following options are recognized: cipher, key, keysize, blocksize 
and padding. Options can be passed like in Crypt::CBC. All options
can be read and also be changed via corresponding methods afterwards.

If called without parameters you have to call at least B<key()> and
B<cipher()> before you can start crypting.

=head2 cipher(), module(), key()

  $ecb = Crypt::ECB->new;
  $ecb->cipher('Blowfish');
  $ecb->key('some_key');

  print $ecb->cipher;	# Blowfish
  print $ecb->module;	# Crypt::Blowfish
  print $ecb->key;	# some_key

or

  my $ecb  = Crypt::ECB->new;
  my $xtea = Crypt::XTEA->new($key, 32, little_endian => 1);
  $ecb->cipher($xtea);

B<cipher()> sets the block cipher to be used. It tries to load the
corresponding module. If an error occurs, it dies with some errmessage.
Otherwise it returns the cipher name. Free packages available for Perl
are for example Blowfish, DES, IDEA or Rijndael. If called without
parameter it just returns the name of the cipher.

B<cipher()> also accepts a pre-existing object from a suitable block
cipher module. This is useful e.g. for cipher modules such as
Crypt::XTEA which need additional parameters.

B<module()> returns the perl package containing the block cipher which
has been specified using cipher().

B<key()> sets the key if given a parameter. It always returns the
key. Note that most block ciphers require keys of definite length.
For example DES expects an eight byte key.

=head2 keysize(), blocksize()

  $ecb = Crypt::ECB->new;
  $ecb->cipher('Blowfish');

  $keysize   = $ecb->keysize;
  $blocksize = $ecb->blocksize;

These methods can be used to retrieve keysize and blocksize as
reported from the block cipher chosen.

They can be used as well to override the values that are reported from
the cipher module. Of course that doesn't make sense unless the block
cipher used supports the new values. E.g. Crypt::Rijndael works with
16, 24 and 32 byte keys.

=head2 padding()

  $ecb->padding('oneandzeroes');

  my $custom_padding = sub { ... };
  $ecb->padding($custom_padding);

B<padding()> sets the way how data is padded up to a multiple of the
cipher's blocksize. Until now the following methods are implemented:
'standard', 'zeroes', 'oneandzeroes', 'rijndael_compat', 'space', 'null'
and 'none'. If the padding style is not set explicitly, 'standard' is used.

  'standard' (default) (binary safe)
  The PKCS#5 / PKCS#7 method (RFC 5652): Pads with the number of bytes
  that should be truncated. So, if blocksize is 8, then "0A0B0C" will
  be padded with five "05"s, resulting in "0A0B0C0505050505". If the
  message is already a multiple of the cipher's block size, then another
  whole block is appended.

  'zeroes' (binary safe)
  This is a variant of the standard method. It pads with null bytes, except
  the last byte equals the number of padding bytes. So, if the blocksize is
  8, then "0A0B0C" will be padded to "0A0B0C0000000005". If the message is
  already a multiple of the cipher's block size, then another whole block
  is appended.

  'oneandzeroes' (binary safe)
  Pads with "80" followed by as many "00"s as necessary to fill the block,
  in other words a 1 bit followed by 0s. If the message already is a
  multiple of the cipher's block size, then another whole block is
  appended.

  'rijndael_compat' (binary safe)
  Similar to oneandzeroes, except that no padding is performed if the
  message already is already a multiple of the cipher's block size. This is
  provided for compatibility with Crypt::Rijndael.

  'null'
  Pads with as many null bytes as necessary to fill the block. If the
  message is already a multiple of the cipher's block size, then another
  whole block is appended.
  ATTENTION: Can truncate more characters than it should (if the original
  message ended with one or more null bytes).

  'space'
  Pads with as many space characters as necessary to fill the block.
  If the message is already a multiple of the cipher's block size, unlike
  the other methods NO block is appended.
  ATTENTION: Can truncate more characters than it should (if the original
  message ended with one or more space characters).

  'none'
  No padding added by Crypt::ECB. You then have to take care of correct
  padding and truncating yourself.

You can also use a custom padding function. To do this, create a function
that is called like:

  $padded_block = function($block, $blocksize, $direction);

and tell Crypt::ECB to use your function:

  $ecb->padding(\&function);

$block is the current block of data, $blocksize is the size to pad to,
$direction is "e" for encrypting and "d" for decrypting, and $padded_block
is the result after padding or truncation. When encrypting, the function
should always return a string of $blocksize length, and when decrypting,
it can expect the string coming in to be of that length.

=head2 start(), mode(), crypt(), finish()

  $ecb->start('encrypt');
  $enc .= $ecb->crypt($_) foreach (@lines);
  $enc .= $ecb->finish;

  $ecb->start('decrypt');
  print $ecb->mode;

B<start()> sets the crypting mode, checks if all required variables
like key and cipher are set, then initializes the block cipher
specified. Allowed parameters are any words starting either with 'e'
or 'd'. The method returns the current mode.

B<mode()> is called without parameters and just returns the current
mode.

B<crypt()> processes the data given as argument. If called without
argument $_ is processed. The method returns the processed data.
Cipher and key have to be set in order to be able to process data.
If some of these are missing or B<start()> was not called before,
the method dies.

After having sent all data to be processed to B<crypt()> you have to
call B<finish()> in order to flush data that's left in the buffer.

=head2 encrypt(), decrypt(), encrypt_hex(), decrypt_hex()

  $enc = $ecb->encrypt($data);
  print $ecb->decrypt($enc);

  $hexenc = $ecb->encrypt_hex($data);
  print $ecb->decrypt_hex($hexenc);

B<encrypt()> and B<decrypt()> are convenience methods which call
B<start()>, B<crypt()> and B<finish()> for you.

B<encrypt_hex()> and B<decrypt_hex()> are convenience functions
that operate on ciphertext in a hexadecimal representation.
These functions can be useful if, for example, you wish to place
the encrypted information into an e-mail message, web page or URL.

=head1 FUNCTIONS

For convenience en- or decrypting can also be done by calling ordinary
functions. The functions are: B<encrypt()>, B<decrypt()>,
B<encrypt_hex()>, B<decrypt_hex()>.

=head2 encrypt(), decrypt(), encrypt_hex(), decrypt_hex()

  use Crypt::ECB qw(encrypt decrypt encrypt_hex decrypt_hex);

  $ciphertext = encrypt($key, $cipher, $plaintext, $padstyle);
  $plaintext  = decrypt($key, $cipher, $ciphertext, $padstyle);

  $ciphertext = encrypt_hex($key, $cipher, $plaintext, $padstyle);
  $plaintext  = decrypt_hex($key, $cipher, $ciphertext, $padstyle);

B<encrypt()> and B<decrypt()> process the provided text and return either
the corresponding ciphertext (encrypt) or plaintext (decrypt). Data
and padstyle are optional. If the padding style is omitted, 'standard'
is assumed. If data is omitted, $_ is used.

B<encrypt_hex()> and B<decrypt_hex()> operate on ciphertext in a
hexadecimal representation, just like the methods with the same name,
see above. Otherwise usage is the same as for B<encrypt()> and
B<decrypt()>.

=head1 BUGS

None that I know of. Please report if you find any.

=head1 TODO

Implement 'random' padding, see http://www.di-mgt.com.au/cryptopad.html.

A taint check on the key like Crypt::CBC does could be added.

=head1 LICENSE

Crypt-ECB is Copyright (C) 2000, 2005, 2008, 2016 by Christoph Appel.

This module is distributed using the same terms as Perl itself. It is free
software; you can redistribute it and/or modify it under the terms of either:

a) the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

b) the "Artistic License".

=head1 AUTHOR

Christoph Appel (see ECB.pm for email address)

=head1 SEE ALSO

perl(1), Crypt::DES(3), Crypt::IDEA(3), Crypt::CBC(3)

=cut
