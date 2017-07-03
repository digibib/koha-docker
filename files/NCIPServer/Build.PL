use Module::Build;
Module::Build->new(
    dist_abstract => 'Main module for NCIP support',
    module_name   => 'NCIP',
    license       => 'gpl',
)->create_build_script;
