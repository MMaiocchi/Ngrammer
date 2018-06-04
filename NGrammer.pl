#!/usr/bin/perl
print "--- NGrammer v.1.4 ---\n";
print "--- code by Massimo Maiocchi  ---\n";
print "--- last update August 2017   ---\n";

use utf8;
use Unicode::Collate;
use utf8::all;
use Cwd;


#load configuration file
open(CONF, "<config.txt") || print "Configuration file missing, the program will process files in the current directory (DEPRECATED - the program will also output files in the current directory)\n\n";
@conf = <CONF>;
close CONF;
foreach $line (@conf) {
    if ($line =~ /working_dir = (.+)/) {
	$working_dir =$1;
    }
}

#load sillabary as hash (sign value => SIGN NAME)
open(S, "<syllabary_CM.txt") || die "Error opening the sillabary: $!\n\n";
@syll_CM = <S>;

%syllabary = "";
foreach $line (@syll_CM) {
    chop $line;
    #deletes possible "?" from sign values
    $line =~ s/\?//;
    @signs = split (/\s+/, $line);
    $uppersign = $signs[0]; 				### delete this block to resolve composite logograms (ex.: azlag3 = GIŠ.TUG2.PI.TE.A.DU) see also below STEP 2 
    $uppersign =~ tr/a-zšşţĝ/A-ZŠŞŢĜ/;			###
    $signs[1] = $uppersign if ($signs[1] =~ m/.+\.\D/); ###
    $syllabary{$signs[0]} = $signs[1];
};


#load additional signs in the syllabary
## NOTE: the readings of these signs are not beyond question, or are used within specific archives (ex. the Ebla archives)
open(AS, "<additional_signs.txt") || print "Error opening the additional signs file: $!\n\n";
@syll_AS = <AS>;
foreach $line (@syll_AS) {
    chop $line;
    #deletes possible "?" from sign values
    $line =~ s/\?//;
    @signs = split (/\s+/, $line);
    $syllabary{$signs[0]} = $signs[1];
    
};


$TIMdir = getcwd();

#load transliteration file(s)
if ($working_dir) {
    print "Found configuration file, the program will process files in $working_dir\n";
    chdir $working_dir || print "Unable to access working directory, as set on config.txt: $!\n";
}
print "Please input file name [ENTER = process all files in working folder, as set on config.txt]: ";
$my_file = <STDIN>;
chomp $my_file;
if ($my_file) { #CASE 1: one big file, individual texts must be introduced by a proper header, for instace: $ A 1.1
    open(FILE, "<$my_file") || die "Error opening file: $!\n\n";
    @texts = <FILE>;
    close FILE;
} else {
    print "... Reading files ...";
    $cwd = getcwd();
    opendir DIR, $cwd or die "cannot open dir $cwd: $!";
    @filelist= readdir DIR;
    closedir DIR;
    foreach $my_file (@filelist) {#CASE 2: many files. Each file may or may not contain header (ex.: $ A 1.1). The program creates headers on the fly, based on filename (ex.: MEE_07_0001 > $ MEE 7.1)
	
	next if ($my_file =~ /^\./);
	next if ($my_file =~ /^syllabary/);
	next if ($my_file =~ /^additional/);
	next if ($my_file =~ /\.htm/);
	next if ($my_file =~ /\.pl/);
	next if ($my_file =~ /^TIM\d/);

	
	open(FILE, "<$my_file") || die "Error opening file: $!\n\n";
	@sourcefile = <FILE>;
	close FILE;
	
        #check for headers in the first line of file
	if ($sourcefile[0] !~ m/^([A-Z].+)/) {
	    $header = $my_file;
	    $header =~ s/\.txt//g;
	    @h_elements = split /\s|_/, $header;
	    $header = '$ '.$h_elements[0].$h_elements[1].'.'.$h_elements[2];
	    unshift @sourcefile, $header
	}	
	
	for ($cc=0; $cc<=$#sourcefile; $cc++) {
	        
	    $texts[$linecount] = $sourcefile[$cc];
	    $linecount++;
	}
	
	#print "HEADER:->$header<-\n";

    }
}

chdir $TIMdir  || print "Unable to navigate to the directory where the script resides: $!\n";

#open warnings
open(W, ">warnings.txt") || print "Error creating the warning log: $!\n\n";

#open results file
open(L, ">results.html") || die "Error creating the result file: $!\n\n";

#open sign index
open(SI, ">sign_index.html") || die "Error creating the sign index: $!\n\n";



print "STEP1: analyzing texts...\n";

for ($n=0; $n<=$#texts; $n++) {
    
    chomp $texts[$n];
    
    next if ($texts[$n] =~ m/^.?\$\$/);
    next if ($texts[$n] =~ m/^.?\-\w\-\w/);
    next if ($texts[$n] =~ m/^\$n/);
    next if ($texts[$n] =~ m/^\$b/);
    
    #deal with different transliteration standards

    #"normalize" line number, ex. "01 10 ma-na KU3.BABBAR" => "l.01 10 ma-na KU3.BABBAR" 
    if ($texts[$n] =~ m/^(\d\d?\d?\'*) /) {
	$texts[$n] =~s/^(\d\d?\d?)\'* /l\.$1 /;
    }
    
    if ($texts[$n] =~ m/^(s)(\d\d?\d?\'*)/) {
	$texts[$n] =~s/^(s)(\d\d?\d?\'*)/$1\.$2/;
    }

    $texts[$n] =~s/s\'/ṣ/g;
    $texts[$n] =~s/s\'/Ṣ/g;
    $texts[$n] =~s/s\"/š/g;
    $texts[$n] =~s/S\"/Š/g;
    $texts[$n] =~s/t'/ṭ/;
    $texts[$n] =~s/T'/Ṭ/;
    $texts[$n] =~s/\[\^/\⌐/g;
    $texts[$n] =~s/\]\^/\¬/g;
    
    #deal with UTF-8 numbers ₀₁₂₃₄₅₆₇₈₉ᵪ
    $texts[$n] =~ tr/₀₁₂₃₄₅₆₇₈₉ᵪ/0123456789x/;
    
    
 
    #change the line "$ A 1.1" in "$A1#1", and "$ TFR1.04E" to "$TFR1#04E". The dot causes problems when splitting lines in to signs.
    $textnum = "";
    if ($texts[$n] =~ m/^\$\s*(\w+)\s*(\d*)\.?\s*(\d*)(\w?)/) {
        $textnum = "\$".$1.$2.'#'.$3.$4; 
	$texts[$n] = $textnum; 
    };
    
    #change a sequence of three or two dots (i.e.: "..." or "..") to the character "…"
    #NOTE: the dot character is reserved for splitting graphs (ex.: IGI.DIB) 
    $texts[$n] =~s/\.\.\./…/g;
    $texts[$n] =~s/\.\./…/g;
    
    #resolve numbers enconded as -: and :-, ex.: 'a3-da-um-=TUG2-:2
    $texts[$n] =~s/\-\:/-/g;
    $texts[$n] =~s/\:\-/-/g;
    
    #change azx(LUL-ZAx) => az(LUL.ZAx)
    ## NOTE: indications within brakets should always use dots and not hyphens.
    if ($texts[$n] =~ m/\(.+\)/){
	    @within_brakets = split (/(\(.+?\))/, $texts[$n]);
	    $texts[$n] = "";
	    for ($h=0; $h<=$#within_brakets; $h++) {
		$within_brakets[$h] =~s/\-/\./g if $within_brakets[$h] =~ /^\(/;
		$texts[$n] = $texts[$n].$within_brakets[$h];
	    }
        };
    
    #split current line in to signs and create the @level1 array
    #NOTE: "composite logograms" and the like are dealt with below (ex.:BA.TI)
    $splitting_graphs = '\s+|\-\=|\=\-|\-\:|\:\-|=\+|\+=|\w\??\_|\-|\:';
    @splitted_tr = split (/($splitting_graphs)/, $texts[$n]);

    foreach $sign (@splitted_tr) {
	$level1[$b] = $sign;
	$b++;
    }
    
};

print "STEP2: processing signs...\n";
@level2 = @level1;

for ($c=0;$c<=$#level2;$c++) {
        
	#"standardize" transliterations
	$level2[$c] =~s/\@x/×/g;
	$level2[$c] =~s/\@\+/\+/g;
	$level2[$c] =~s/\@\^//g;
	$level2[$c] =~s/\@\'//g;
	$level2[$c] =~s/\@\.//g;
	$level2[$c] =~s/\@\>//g;
	$level2[$c] =~s/\@\://g;
	$level2[$c] =~s/\@\<//g;
	$level2[$c] =~s/\@\\/\@t/g;
	$level2[$c] =~s/\@\;/\@g/g;
	$level2[$c] =~s/\@\//\@g/g;
	$level2[$c] =~s/\@\|/\&/g;
	$level2[$c] =~s/\@\#/\@/g;
	
		
	#resolve problematic readings, ex.: amex(|E2.SAL|) => E2.SAL, unug!(AB) => AB, az0(LUL-ZAx) => LUL.ZAx
        if ($level2[$c] =~ m/\(\|?([^\|]+)\|?\)/g) {
	    $level2[$c] = $1;	    
        };
	
        #remove unwanted glyphs
        ##NOTE: signs included within  "< >" or "<< >>" are treated as every other sign
	$unwanted_glyphs = '(\"|\*|\?|\!|\(|\)|\[|\]|\{|\}|\<\<|\>\>|\<|\>)';
	if ($level2[$c] !~ m/^([l|r|r|v|l|s]e?\??\.\??\!?!?\+?.+)$/) {
	    $level2[$c] =~s/$unwanted_glyphs//g;
	    $level2[$c] =~s/$splitting_graphs//g;
	}
	
	#resolve readings of signs separated with dot (ex. E2.SAL)
        @additional_signs = "";
	@additional_signs_level1 = "";
	if (($level2[$c] =~ m/\.\D/) && ($level2[$c] !~ m/^([l|r|r|v|l|s]e?\??\.\??\!?!?\+?.+)$/)) {
	     
            @additional_signs = split (/\./, $level2[$c]);
	    @additional_signs_level1 = split (/(\.)/, $level1[$c]);
            splice (@level2, $c, 1, @additional_signs);
	    $level2[$c] = $additional_signs[0];
	    @extra_array = "";
	    $w=0;
	    for ($k=0;$k<=$#additional_signs;$k++) {
		$extra_array[$k]= $additional_signs_level1[$w].$additional_signs_level1[$w+1];
		$w = $w+2
	    }
	    splice (@level1, $c, 1, @extra_array);            
        };
		
	#resolve composite logograms (ex.: azlag3 = GIŠ.TUG2.PI.TE.A.DU)
	#NOTE: this changes azlag3 to azlag3(GIŠ.TUG2.PI.TE.A.DU) on level1, and to GIŠ.TUG2.PI.TE.A.DU on level2 
	@additional_logograms = "";
	@additional_logograms_level1 = "";
	@extra_array_logograms= "";
	$actual_reading = "";
	if ($syllabary{$level2[$c]} =~ m/\.\D/) {
            @additional_logograms = split (/\./, $syllabary{$level2[$c]});
	    @additional_logograms_level1 = split (/(\.)/, $syllabary{$level2[$c]});
	    $actual_reading = $level1[$c];       
            splice (@level2, $c, 1, @additional_logograms);
	    
	    for ($k=0;$k<=$#additional_logograms;$k++) {
		$extra_array_logograms[$k]= $additional_logograms_level1[$w].$additional_logograms_level1[$w+1];
		$w = $w+2
	    }
            splice (@level1, $c, 1, @extra_array_logograms);
	    $level1[$c] = $actual_reading."(".$additional_logograms[0].".";
	    $level1[$c+$#additional_logograms] = $additional_logograms[$#additional_logograms].")";
	    
        };
        
	#resolve readings with x, ex.: LU0 => LUx, ZAM0 => ZAMx, etc. (NOTE: this does not affect GUR10)
	if ($level2[$c] =~ m/([a-zA-ZĝĜţŢšŠ\&\.\@×\?\!]+)(0)$/) {
	    $level2[$c] = $1."x";
	}
	
	#escaping < > in HTML
	$level1[$c] =~s/</&\#60\;/g;
	$level1[$c] =~s/>/&\#62\;/g;
            
};    

#for ($z=0;$z<=$#level1;$z++) {
#    print "LEVEL1: >$level1[$z]< \t\t LEVEL2: >$level2[$z]<\n";
#}

print "STEP3: triadic analysis...\n";

for ($p=0; $p<=$#level2-2; $p++) {
    @triad = "";
    next if (!$level2[$p]);    
    
    if ($level2[$p] =~ m/^(\$.+)/) {
        $text_num = $1;
	print "...processing text $text_num\n";
	next;
    }
    if ($level2[$p] =~ m/^([r|l|r|v|l|s]e?\??\.\??\!?!?\+?.+)$/) {
	$obv_rev = $1;

	next;
    }

    #output warnings if a sign is not in the sillabary
    if ((!$syllabary{$level2[$p]}) && ($level2[$p])) {
	$word_range = 8;
	$context_after = "";
	$context_before = ""; 
	for ($t=1;$t<=$word_range;$t++) {
	    $context_after = $context_after.$level1[$p+$t];
	}
	for ($t=$word_range;$t>1;$t--) {
	    $context_before = $context_before.$level1[$p-$t];
	}
	$context = $context_before."-->".$level1[$p]."<--".$context_after;
	$warnings{$level2[$p]} = $warnings{$level2[$p]}."\tHERE\> $text_num $obv_rev \> $context\n" if $level2[$p] !~ m/^re?\??\!?\.|^v\??\!?\.|^le\??\!?\.|^\d+|^,|^\$|^\+|cb[0-9]+|^ln[0-9]+|^ce[0-9]*$|^cr[0-9]+|^rs|^\+?[N|n]$|^[N|n]\+|^ARET|AA|^c$|^cv$|^vs$|^w[w|s|h|v]?$|^FI|^p$|^be,|^te,|^le,|^re,/;
    };
    
    #set first element of the triad
    $triad[0] = $syllabary{$level2[$p]};
    
    #look for the second non-empty element of the triad
    $triad_range = "0";
    $first_interval = "0";
    $second_interval = "0";

    for ($q=$p+1; $q<=$#level2-1; $q++) {
	$first_interval++;
	if (($level2[$q]) && ($level2[$q] !~ m/^([l|r|r|v|l|s]e?\??\.\??\!?!?\+?.+)$/)) {
	    $triad[1] = $syllabary{$level2[$q]};
	    for ($r=$q+1; $r<=$#level2; $r++) {
		$second_interval++;
		if (($level2[$r]) && ($level2[$r] !~ m/^([l|r|r|v|l|s]e?\??\.\??\!?!?\+?.+)$/)) {
		$triad[2]= $syllabary{$level2[$r]};
		last;
		}
	    }
	last;
	}
    }

    $triad_range = $first_interval+$second_interval;
    
    #get triad context
    $sign_range = 8;
    $context_after_triad = "";
    $context_before_triad = "";
    $context_triad = "";
    $context_before_for_sign_index = "";
    $context_after_for_sign_index  = "";
    $context_triad_for_sign_index  = "";
    $count_after_triad = 0;
    $count_before_triad = 0;
    $count = 0;
    $end_after = "";

    #context after triad
    for ($t=$p+$triad_range+1;$t<=$#level2;$t++) {
	$count++;
	$count_after_triad++ if ($level2[$t]);
	if ($level2[$t] =~ m/^\$/) {
	    $end_after = "//";
	    $count--;
	    last;
	}
	last if ($count_after_triad eq $sign_range);
    }
    
     
    $context_after_triad = join('', @level1[$p+$triad_range+1..$p+$triad_range+$count]).$end_after;
        
    
    #context before triad 
    $count = 0;
    $end_before = "";
    for ($t=$p-1;$t>=0;$t--) {
	$count++;
	$count_before_triad++ if $level2[$t];
	if ($level2[$t-1] =~ m/^.?\$/) {
	    $end_before = "//";
	    $count--;
	    last;
	}
	last if $count_before_triad eq $sign_range;	
    }
    
    $context_before_triad = $end_before.join('', @level1[$p-$count..$p-1]);
    
    $context_triad = join('', @level1[$p..$p+$triad_range]);
    
    $context_triad_for_sign_index = $context_triad; #brakets will be stripped off later

    #context after triad for sign index
    $context_after_for_sign_index = "";
    $count = 0;
     for ($t=$p+$triad_range+1;$t<=$#level2;$t++) {
	$count++;
	if ($level1[$t] =~ m/\s+/) {
	    $count--;
	    last;
	}
	if ($level1[$t] =~ m/^.?\$/) {
	    $count--;
	    last;
	}
   }
       
    $context_after_for_sign_index = join('', @level1[$p+$triad_range+1..$p+$triad_range+$count]);


    #context before triad for sign index
    $count = 0;
    $context_before_for_sign_index = "";
    for ($t=$p-1;$t>=0;$t--) {
	$count++;
	if ($level1[$t] =~ m/^.?\s+/) {
	    $count--;
	    last;
	}
	if ($level1[$t] =~ m/^.?\$/) {
	    $count--;
	    last;
	}
    }
    
    $context_before_for_sign_index = join('', @level1[$p-$count..$p-1]);
        

    $context_before_triad 	   =~ s/[r|le|r|v|l|s]e?\??\.[\d|\'|\!|\?|\+\,]+a?b?c?d?e?f?g?/ \//g;
    $context_after_triad  	   =~ s/[r|le|r|v|l|s]e?\??\.[\d|\'|\!|\?|\+\,]+a?b?c?d?e?f?g?/ \//g;
    $context_triad        	   =~ s/[r|le|r|v|l|s]e?\??\.[\d|\'|\!|\?|\+\,]+a?b?c?d?e?f?g?/ \//g;
    $context_before_for_sign_index =~ s/[r|le|r|v|l|s]e?\??\.[\d|\'|\!|\?|\+\,]+a?b?c?d?e?f?g?//g;
    $context_before_for_sign_index =~ s/[\[|\]|\?|\!|\{|\}]//g;
    $context_before_for_sign_index =~ s/\w_//g;
    $context_after_for_sign_index  =~ s/[r|l|r|v|l|s]e?\??\.[\d|\'|\!|\?|\+\,]+a?b?c?d?e?f?g?//g;
    $context_after_for_sign_index  =~ s/[\[|\]|\?|\!|\{|\}]//g;
    $context_after_for_sign_index  =~ s/\w_//g;
    $context_triad_for_sign_index  =~ s/[r|l|r|v|l|s]e?\??\.[\d|\'|\!|\?|\+\,]+a?b?c?d?e?f?g?/ \//g;
    $context_triad_for_sign_index  =~ s/[\[|\]|\?|\!|\<|\>|\{|\}]//g;   
    $context_triad_for_sign_index  =~ s/\w_//g;
    
    $reference = "$text_num"." "."$obv_rev"." ";
    
    #include the non-empty triad as first result
    $actual_triad = "";
    if (($triad[0]) && ($triad[1])  && ($triad[2])) {
	$actual_triad = "$triad[0] $triad[1] $triad[2]";
	$results{$actual_triad} = $results{$actual_triad}."\t".$context_before_triad."<b><font color=\"\#0000FF\">".$context_triad."</font></b>".$context_after_triad."\t".$reference."\n" if ($context_triad !~ m/ \//); #delete "if ..." statement to include multiline triads
	#create a hash pair "TRIAD => readings" if the TRIAD doesn't exist yet in the keys of the hash. This provides the possibility to mark triads having multiple readings. 
	
	if ($context_triad_for_sign_index !~ m/ \//) { #delete "if..." statement to include multiline triads
	    $reading_check{$actual_triad} = $context_triad_for_sign_index if (!exists $reading_check{$actual_triad});
	    
	    
	    $sign_index_count{$actual_triad}{$context_triad_for_sign_index}{$context_before_for_sign_index."<b><font color=\"\#0000FF\">".$context_triad_for_sign_index."</font></b>".$context_after_for_sign_index}++ if ($context_triad_for_sign_index eq $reading_check{$actual_triad});
	    $sign_index_count{$actual_triad}{$context_triad_for_sign_index}{$context_before_for_sign_index."<b><font color=\"\#FF0000\">".$context_triad_for_sign_index."</font></b>".$context_after_for_sign_index}++ if ($context_triad_for_sign_index ne $reading_check{$actual_triad});
	
	
	  
	}
    }
}

print "STEP4: sorting and printing results to file...";

print L "<HTML>\n<HEAD>\n";
print L "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />\n";
print L "</HEAD>\n<BODY>\n<pre>\n";

print SI "<HTML>\n<HEAD>\n";
print SI "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />\n";
print SI "</HEAD>\n<BODY>\n<pre>\n";


my $collator = Unicode::Collate->new(table => undef); #returns an object
my @sorted_keys = $collator->sort(keys (%results));


foreach $triad (@sorted_keys) {
    print L "<p>$triad $results{$triad}</p>\n";
}
print L "</pre></BODY>\n</HTML>";


my @sorted_keys_sign_index = $collator->sort(keys (%sign_index_count));

print SI "<h1>Triadic index to Ebla</h1>Column 1 - signs<br>Column 2 – total readings of individual triads<br>Column 3 - context<br>Column 4 - total instances of individual segments<br>
<table border=1>\n<tr>\n  <td><b>1</b></td>\n  <td><b>2</b></td>\n  <td><b>3</b></td>\n  <td><b>4</b></td>\n</tr>\n";

foreach $triad (@sorted_keys_sign_index) {
    
    #getting rowspan for the individual triads
    foreach $context_triad ($collator->sort(keys %{$sign_index_count{$triad}})) {
	foreach $context_item ($collator->sort(keys $sign_index_count{$triad}{$context_triad})) {
	    $row_span{$triad}++;
	}
    }	
    $odd_or_even++;
    $rowcolor = "E8E8E8" if (0 == $odd_or_even % 2);
    $rowcolor = "FFFFFF" if (0 != $odd_or_even % 2);
    $multiple_readings = scalar keys $sign_index_count{$triad};
   
    print SI "<tr BGCOLOR=\"$rowcolor\">";
    print SI "<td rowspan = $row_span{$triad}>$triad</td>\n";
    print SI "<td rowspan = $row_span{$triad}>$multiple_readings</td>\n";
    
    $num = 0;
    @numbered_items = "";
    
    foreach $context_triad ($collator->sort(keys %{$sign_index_count{$triad}})) {	
        foreach $context_item ($collator->sort(keys $sign_index_count{$triad}{$context_triad})) {
	    $numbered_items[$num] = "<td>$context_item</td><td>$sign_index_count{$triad}{$context_triad}{$context_item}</td></tr>";
	    $num++;	    
	}   	
    }
    print SI "$numbered_items[0]\n";	
	for ($n=1; $n<$num; $n++) {
	   print SI "<tr BGCOLOR=\"$rowcolor\">$numbered_items[$n]\n";
	   print SI "\n";	
	}
}


print SI "</table>";
print SI "</pre></BODY>\n</HTML>";

if (%warnings) {
    print W "WARNING: the following signs are missing in the syllabary:\n";
    print "\nWARNING: typos or inconsistencies possibly found within the transliterations. Please refer to the file \"warnings.txt\" in the current directory.\n";
    foreach $warning (keys (%warnings)) {
                print W "$warning\t $warnings{$warning}\n";
    };
};

close R;
close L;
close W;
close S;
close FILE;
