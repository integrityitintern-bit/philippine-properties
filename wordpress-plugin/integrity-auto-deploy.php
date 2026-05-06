<?php
/**
 * Plugin Name:  Integrity Realty — Auto Deploy
 * Description:  Triggers a Cloudflare Pages rebuild when a property is published, and emails admin when a new listing draft is submitted via the website.
 * Version:      1.1.0
 * Author:       Integrity Realty
 */

if ( ! defined( 'ABSPATH' ) ) exit;

define( 'INTEGRITY_CF_HOOK', 'https://api.cloudflare.com/client/v4/workers/builds/deploy_hooks/3a6cf029-74fe-4da9-b7b7-282b21667296' );

// ── 1. Auto-deploy to Cloudflare when a property is published ─────────────────
function integrity_trigger_deploy( $post_id, $post, $update ) {
    if ( ! in_array( $post->post_type, array( 'estate_property', 'property' ) ) ) return;
    if ( $post->post_status !== 'publish' ) return;
    if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) return;
    if ( wp_is_post_revision( $post_id ) ) return;
    // Debounce: only fire once per minute
    if ( get_transient( 'integrity_cf_deploying' ) ) return;
    set_transient( 'integrity_cf_deploying', 1, 60 );

    wp_remote_post( INTEGRITY_CF_HOOK, array(
        'method'   => 'POST',
        'timeout'  => 5,
        'blocking' => false,
    ) );
}
add_action( 'save_post', 'integrity_trigger_deploy', 10, 3 );

// ── 2. Email admin when a new property draft is created via the website ───────
function integrity_notify_new_draft( $post_id, $post, $update ) {
    if ( ! in_array( $post->post_type, array( 'estate_property', 'property' ) ) ) return;
    if ( $post->post_status !== 'draft' ) return;
    if ( $update ) return; // only new posts, not edits
    if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) return;
    if ( wp_is_post_revision( $post_id ) ) return;

    $admin_email = get_option( 'admin_email' );
    $edit_link   = admin_url( 'post.php?post=' . $post_id . '&action=edit' );
    $subject     = '📋 New Property Listing Submitted: ' . $post->post_title;
    $message     = "A new property listing has been submitted via the website and is waiting for your review.\n\n"
                 . "Title: " . $post->post_title . "\n"
                 . "Review & Publish: " . $edit_link . "\n\n"
                 . "Once you click Publish, the site will automatically rebuild and the listing will go live.";

    wp_mail( $admin_email, $subject, $message );
}
add_action( 'save_post', 'integrity_notify_new_draft', 10, 3 );
