import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';
import { Project } from './project.entity';
import { Report } from './report.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Project, Report])],
  controllers: [ProjectsController],
  providers: [ProjectsService],
})
export class ProjectsModule {}
