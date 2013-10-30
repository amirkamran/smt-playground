for (<Seeds/*.pm>) {
    print $_."\n";
    system ("perl generate-step.pl $_");
}
