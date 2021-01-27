# coding=utf-8
"""Tests that publish file plugin repositories."""
import unittest
from random import choice

from pulp_smash import config
from pulp_smash.pulp3.bindings import monitor_task
from pulp_smash.pulp3.utils import gen_repo, get_content, get_versions, modify_repo
from pulpcore.client.pulp_file import (
    FileFilePublication,
    PublicationsFileApi,
    RemotesFileApi,
    RepositoriesFileApi,
    RepositorySyncURL,
)
from pulpcore.client.pulp_file.exceptions import ApiException

from pulp_file.tests.functional.constants import FILE_CONTENT_NAME
from pulp_file.tests.functional.utils import gen_file_client, gen_file_remote
from pulp_file.tests.functional.utils import set_up_module as setUpModule  # noqa:F401


class PublishAnyRepoVersionTestCase(unittest.TestCase):
    """Test whether a particular repository version can be published.

    This test targets the following issues:

    * `Pulp #3324 <https://pulp.plan.io/issues/3324>`_
    * `Pulp Smash #897 <https://github.com/pulp/pulp-smash/issues/897>`_
    """

    @classmethod
    def setUpClass(cls):
        """Create class-wide variables."""
        cls.cfg = config.get_config()

        client = gen_file_client()
        cls.repo_api = RepositoriesFileApi(client)
        cls.remote_api = RemotesFileApi(client)
        cls.publications = PublicationsFileApi(client)

    def setUp(self):
        """Create a new repository before each test."""
        body = gen_file_remote()
        remote = self.remote_api.create(body)
        self.addCleanup(self.remote_api.delete, remote.pulp_href)

        repo = self.repo_api.create(gen_repo())
        self.addCleanup(self.repo_api.delete, repo.pulp_href)

        repository_sync_data = RepositorySyncURL(remote=remote.pulp_href)
        sync_response = self.repo_api.sync(repo.pulp_href, repository_sync_data)
        monitor_task(sync_response.task)

        self.repo = self.repo_api.read(repo.pulp_href)

    def test_all(self):
        """Test whether a particular repository version can be published.

        1. Create a repository with at least 2 repository versions.
        2. Create a publication by supplying the latest ``repository_version``.
        3. Assert that the publication ``repository_version`` attribute points
           to the latest repository version.
        4. Create a publication by supplying the non-latest ``repository_version``.
        5. Assert that the publication ``repository_version`` attribute points
           to the supplied repository version.
        6. Assert that an exception is raised when providing two different
           repository versions to be published at same time.
        """
        # Step 1
        for file_content in get_content(self.repo.to_dict())[FILE_CONTENT_NAME]:
            modify_repo(self.cfg, self.repo.to_dict(), remove_units=[file_content])
        version_hrefs = tuple(ver["pulp_href"] for ver in get_versions(self.repo.to_dict()))
        non_latest = choice(version_hrefs[:-1])

        # Step 2
        publish_data = FileFilePublication(repository=self.repo.pulp_href)
        publication = self.create_publication(publish_data)

        # Step 3
        self.assertEqual(publication.repository_version, version_hrefs[-1])

        # Step 4
        publish_data = FileFilePublication(repository_version=non_latest)
        publication = self.create_publication(publish_data)

        # Step 5
        self.assertEqual(publication.repository_version, non_latest)

        # Step 6
        with self.assertRaises(ApiException):
            body = {"repository": self.repo.pulp_href, "repository_version": non_latest}
            self.publications.create(body)

    def test_custom_manifest(self):
        """Test whether a repository version can be published with a specified manifest."""
        publish_data = FileFilePublication(repository=self.repo.pulp_href)
        publication = self.create_publication(publish_data)
        self.assertEqual(publication.manifest, "PULP_MANIFEST")

        publish_data = FileFilePublication(repository=self.repo.pulp_href, manifest="listing")
        publication = self.create_publication(publish_data)
        self.assertEqual(publication.manifest, "listing")

    def create_publication(self, publish_data):
        """Create a new publication from the passed data."""
        publish_response = self.publications.create(publish_data)
        created_resources = monitor_task(publish_response.task).created_resources
        publication_href = created_resources[0]
        self.addCleanup(self.publications.delete, publication_href)
        return self.publications.read(publication_href)
